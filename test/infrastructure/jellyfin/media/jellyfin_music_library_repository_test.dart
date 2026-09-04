import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/jellyfin_media_api.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinMusicLibraryRepository.dart';

import '../../../support/FakeDioAdapter.dart';
import '../../../support/FakeSessionContext.dart';

const _artistId = MediaId(serverId: 'server-1', itemId: 'artist-1');
const _albumId = MediaId(serverId: 'server-1', itemId: 'album-1');
const _elsewhere = MediaId(serverId: 'server-2', itemId: 'album-1');

JellyfinMusicLibraryRepository _repository(
  FakeDioAdapter adapter, {
  FakeSessionContext? context,
}) {
  return JellyfinMusicLibraryRepository(
    testMediaApi(adapter, context: context),
  );
}

void main() {
  test('lists album artists as domain artists', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(
        itemsResponse([
          {'Id': 'artist-1', 'Name': 'Miles Davis', 'Type': 'MusicArtist'},
        ], totalRecordCount: 4200),
      ),
    );

    final result = await _repository(adapter).artists();

    final page = result.valueOrNull!;
    expect(adapter.requests.single.path, JellyfinMediaApi.albumArtistsPath);
    expect(page.items.single.name, 'Miles Davis');
    expect(page.items.single.id, _artistId);
    expect(page.totalCount, 4200);
    expect(page.hasMore, isTrue);
  });

  test('asks only for the requested window of a huge library', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    await _repository(
      adapter,
    ).tracks(page: const PageRequest(startIndex: 129900, limit: 100));

    final query = adapter.requests.single.queryParameters;
    expect(query['startIndex'], 129900);
    expect(query['limit'], 100);
    expect(query['includeItemTypes'], 'Audio');
  });

  test(
    "filters an artist's albums server-side and orders them by year",
    () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(itemsResponse(const [])),
      );

      await _repository(adapter).albums(artistId: _artistId);

      final query = adapter.requests.single.queryParameters;
      expect(query['albumArtistIds'], 'artist-1');
      expect(query['includeItemTypes'], 'MusicAlbum');
      expect(query['sortBy'], 'ProductionYear,SortName');
    },
  );

  test('orders an album in disc and track order', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    await _repository(adapter).tracks(albumId: _albumId);

    final query = adapter.requests.single.queryParameters;
    expect(query['parentId'], 'album-1');
    expect(query['sortBy'], 'ParentIndexNumber,IndexNumber');
  });

  test(
    'keeps the usable tracks of an album that has an unreadable one',
    () async {
      // The roadmap's twelve-track album with one bad track: eleven songs
      // and one marked entry, not a failed screen.
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {'Id': 't1', 'Name': 'So What', 'Type': 'Audio'},
            {'Id': 't2', 'Type': 'Audio'},
            {'Id': 't3', 'Name': 'Blue in Green', 'Type': 'Audio'},
          ]),
        ),
      );

      final result = await _repository(adapter).tracks(albumId: _albumId);

      final page = result.valueOrNull!;
      expect(page.items.map((track) => track.name), [
        'So What',
        'Blue in Green',
      ]);
      expect(page.unavailable.single.id, 't2');
      expect(page.hasUnavailable, isTrue);
    },
  );

  test('loads one album', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(
        itemsResponse([
          {
            'Id': 'album-1',
            'Name': 'Kind of Blue',
            'Type': 'MusicAlbum',
            'ProductionYear': 1959,
          },
        ]),
      ),
    );

    final result = await _repository(adapter).album(_albumId);

    expect(result.valueOrNull!.productionYear, 1959);
    expect(adapter.requests.single.queryParameters['ids'], 'album-1');
  });

  test('reports a removed album as unavailable rather than empty', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    final result = await _repository(adapter).album(_albumId);

    expect(result.failureOrNull, isA<UnavailableFailure>());
  });

  test('will not query one server for another server\'s item', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    final result = await _repository(adapter).album(_elsewhere);

    expect(result.failureOrNull, isA<UnavailableFailure>());
    expect(adapter.callCount, isZero);
  });

  test('fails cleanly when nobody is signed in', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    final result = await _repository(
      adapter,
      context: FakeSessionContext.signedOut(),
    ).artists();

    expect(result.failureOrNull, isA<UnauthorizedFailure>());
    expect(adapter.callCount, isZero);
  });

  test('passes a server failure through as a failure', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({}, statusCode: 500),
    );

    final result = await _repository(adapter).artists();

    expect(result.isErr, isTrue);
  });

  test('searches each category server-side, not in Dart', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );
    final repository = _repository(adapter);

    await repository.artists(searchTerm: 'miles');
    await repository.albums(searchTerm: 'miles');
    await repository.tracks(searchTerm: 'miles');

    expect(adapter.requests.map((r) => r.queryParameters['searchTerm']), [
      'miles',
      'miles',
      'miles',
    ]);
    // Still a window, still one category per query — a music search must
    // not turn into "fetch the library and filter it".
    expect(
      adapter.requests.map((r) => r.queryParameters['limit']),
      everyElement(PageRequest.defaultLimit),
    );
    expect(adapter.requests.last.queryParameters['includeItemTypes'], 'Audio');
  });

  test('treats a blank search term as no search at all', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    await _repository(adapter).albums(searchTerm: '   ');

    expect(
      adapter.requests.single.queryParameters.containsKey('searchTerm'),
      isFalse,
    );
  });

  test('keeps a search inside one artist when asked', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    await _repository(adapter).tracks(artistId: _artistId, searchTerm: 'blue');

    final query = adapter.requests.single.queryParameters;
    expect(query['artistIds'], 'artist-1');
    expect(query['searchTerm'], 'blue');
  });
}
