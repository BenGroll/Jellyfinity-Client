import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinPlaylistRepository.dart';
import 'package:jellyfinity/infrastructure/media/CachedPlaylistRepository.dart';
import 'package:jellyfinity/infrastructure/persistence/media/MediaCollectionKey.dart';

import '../../support/FakeDioAdapter.dart';
import '../../support/FakeSessionContext.dart';
import '../../support/media_fakes.dart';

const _playlistId = MediaId(serverId: 'server-1', itemId: 'pl-1');

FakeDioAdapter _offline() => FakeDioAdapter(
  (options) async => throw DioException.connectionError(
    requestOptions: options,
    reason: 'offline',
  ),
);

FakeDioAdapter _answering(List<Map<String, dynamic>> items) =>
    FakeDioAdapter((_) async => jsonResponseBody(itemsResponse(items)));

CachedPlaylistRepository _repository(
  FakeDioAdapter adapter,
  RecordingMediaCacheStore cache,
) {
  final context = FakeSessionContext();
  return CachedPlaylistRepository(
    JellyfinPlaylistRepository(testMediaApi(adapter, context: context)),
    cache,
    context,
  );
}

void main() {
  test('saves each playlist under its own key', () async {
    final cache = RecordingMediaCacheStore();

    await _repository(
      _answering([
        {'Id': 'pl-1', 'Name': 'Late Night', 'Type': 'Playlist'},
      ]),
      cache,
    ).playlists();
    await _repository(
      _answering([
        {'Id': 't1', 'Name': 'So What', 'Type': 'Audio'},
      ]),
      cache,
    ).tracks(_playlistId);

    expect(cache.savedPages, [
      MediaCollectionKey.playlists,
      MediaCollectionKey.tracksOfPlaylist('pl-1'),
    ]);
  });

  test('gives back the playlist the user built, in their order', () async {
    final cache = RecordingMediaCacheStore();
    await _repository(
      _answering([
        {'Id': 't1', 'Name': 'So What', 'Type': 'Audio'},
        // A film someone dropped into a music playlist: not a song, and
        // it has to keep its place or every number after it shifts.
        {'Id': 'm1', 'Name': 'Heat', 'Type': 'Movie'},
        {'Id': 't2', 'Name': 'Blue in Green', 'Type': 'Audio'},
      ]),
      cache,
    ).tracks(_playlistId);

    final result = await _repository(_offline(), cache).tracks(_playlistId);

    final page = result.valueOrNull!;
    expect(page.items.map((t) => t.name), ['So What', 'Blue in Green']);
    expect(page.unavailable.single.id, 'm1');
    expect(page.consumed, 3);
    expect(page.source, PageSource.cache);
  });

  test('passes the failure through when nothing was ever saved', () async {
    final result = await _repository(
      _offline(),
      RecordingMediaCacheStore(),
    ).playlists();

    expect(result.isErr, isTrue);
  });
}
