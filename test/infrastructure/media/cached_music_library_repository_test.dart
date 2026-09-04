import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinMusicLibraryRepository.dart';
import 'package:jellyfinity/infrastructure/media/CachedMusicLibraryRepository.dart';
import 'package:jellyfinity/infrastructure/persistence/media/MediaCollectionKey.dart';

import '../../support/FakeDioAdapter.dart';
import '../../support/FakeSessionContext.dart';
import '../../support/media_fakes.dart';

const _artistId = MediaId(serverId: 'server-1', itemId: 'artist-1');
const _albumId = MediaId(serverId: 'server-1', itemId: 'album-1');

/// A server that cannot be reached at all — the case the local copy
/// exists for.
FakeDioAdapter _offline() => FakeDioAdapter(
  (options) async => throw DioException.connectionError(
    requestOptions: options,
    reason: 'offline',
  ),
);

FakeDioAdapter _answering(List<Map<String, dynamic>> items, {int? total}) =>
    FakeDioAdapter(
      (_) async =>
          jsonResponseBody(itemsResponse(items, totalRecordCount: total)),
    );

({CachedMusicLibraryRepository repository, RecordingMediaCacheStore cache})
_repository(FakeDioAdapter adapter, {RecordingMediaCacheStore? cache}) {
  final context = FakeSessionContext();
  final store = cache ?? RecordingMediaCacheStore();
  return (
    repository: CachedMusicLibraryRepository(
      JellyfinMusicLibraryRepository(testMediaApi(adapter, context: context)),
      store,
      context,
    ),
    cache: store,
  );
}

const _albumRow = {
  'Id': 'album-1',
  'Name': 'Kind of Blue',
  'Type': 'MusicAlbum',
  'ProductionYear': 1959,
};

void main() {
  test('a served page is current, and is saved on the way past', () async {
    final (:repository, :cache) = _repository(_answering([_albumRow]));

    final result = await repository.albums();

    expect(result.valueOrNull!.source, PageSource.server);
    expect(result.valueOrNull!.items.single.name, 'Kind of Blue');
    expect(cache.savedPages, [MediaCollectionKey.albums]);
  });

  test('an unreachable server is answered from the saved copy', () async {
    final cache = RecordingMediaCacheStore();
    await _repository(
      _answering([_albumRow]),
      cache: cache,
    ).repository.albums();

    final offline = _repository(_offline(), cache: cache).repository;
    final result = await offline.albums();

    final page = result.valueOrNull!;
    expect(page.items.single.name, 'Kind of Blue');
    expect(page.source, PageSource.cache);
    // Saved metadata, unreachable media: the UI must be able to say so
    // rather than offering a song it cannot play.
    expect(page.items.single.availability, MediaAvailability.remoteUnavailable);
  });

  test('with nothing saved, the failure is the answer', () async {
    final (:repository, cache: _) = _repository(_offline());

    final result = await repository.albums();

    // An empty list would claim the library is empty, which is a
    // different and wrong thing to tell the user.
    expect(result.failureOrNull, isA<RecoverableFailure>());
  });

  test("does not resurrect what the server says is gone", () async {
    final cache = RecordingMediaCacheStore();
    await _repository(
      _answering([_albumRow]),
      cache: cache,
    ).repository.album(_albumId);

    // The server answered — the album is simply not there any more.
    final gone = _repository(_answering(const []), cache: cache).repository;
    final result = await gone.album(_albumId);

    expect(result.failureOrNull, isA<UnavailableFailure>());
  });

  test('keeps a detail header readable when the server drops', () async {
    final cache = RecordingMediaCacheStore();
    await _repository(
      _answering([_albumRow]),
      cache: cache,
    ).repository.album(_albumId);

    final result = await _repository(
      _offline(),
      cache: cache,
    ).repository.album(_albumId);

    expect(result.valueOrNull!.productionYear, 1959);
    expect(
      result.valueOrNull!.availability,
      MediaAvailability.remoteUnavailable,
    );
  });

  test('files a discography under the artist it belongs to', () async {
    final (:repository, :cache) = _repository(_answering([_albumRow]));

    await repository.albums(artistId: _artistId);
    await repository.tracks(albumId: _albumId);
    await repository.tracks(artistId: _artistId);

    expect(cache.savedPages, [
      MediaCollectionKey.albumsOfArtist('artist-1'),
      MediaCollectionKey.tracksOfAlbum('album-1'),
      MediaCollectionKey.tracksOfArtist('artist-1'),
    ]);
  });

  test('never saves or serves a search from the cache', () async {
    final cache = RecordingMediaCacheStore();
    await _repository(
      _answering([_albumRow]),
      cache: cache,
    ).repository.albums(searchTerm: 'blue');
    expect(cache.savedPages, isEmpty);

    // Offline, a search says it needs the server rather than quietly
    // searching the fraction of the library that happens to be saved.
    await _repository(
      _answering([_albumRow]),
      cache: cache,
    ).repository.albums();
    final result = await _repository(
      _offline(),
      cache: cache,
    ).repository.albums(searchTerm: 'blue');

    expect(result.isErr, isTrue);
  });

  test('does not reach for the cache when nobody is signed in', () async {
    final context = FakeSessionContext.signedOut();
    final cache = RecordingMediaCacheStore();
    final repository = CachedMusicLibraryRepository(
      JellyfinMusicLibraryRepository(
        testMediaApi(_offline(), context: context),
      ),
      cache,
      context,
    );

    final result = await repository.albums();

    expect(result.failureOrNull, isA<UnauthorizedFailure>());
  });
}
