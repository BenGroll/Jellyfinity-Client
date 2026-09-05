import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinPlaylistRepository.dart';

import '../../../support/FakeDioAdapter.dart';
import '../../../support/FakeSessionContext.dart';

const _playlistId = MediaId(serverId: 'server-1', itemId: 'pl-1');

JellyfinPlaylistRepository _repository(FakeDioAdapter adapter) =>
    JellyfinPlaylistRepository(testMediaApi(adapter));

void main() {
  test('lists playlists with the count a row displays', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(
        itemsResponse([
          {
            'Id': 'pl-1',
            'Name': 'Late Night',
            'Type': 'Playlist',
            'ChildCount': 38,
          },
        ]),
      ),
    );

    final result = await _repository(adapter).playlists();

    final playlist = result.valueOrNull!.items.single;
    expect(playlist.name, 'Late Night');
    expect(playlist.itemCount, 38);
    expect(
      adapter.requests.single.queryParameters['fields'],
      contains('ChildCount'),
    );
  });

  test('reads a playlist from its own endpoint, in its own order', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    await _repository(adapter).tracks(_playlistId);

    final request = adapter.requests.single;
    expect(request.path, '/Playlists/pl-1/Items');
    // No sort parameter: the order is the one the user arranged.
    expect(request.queryParameters, isNot(contains('sortBy')));
  });

  test('keeps an entry that is not a song, marked, in its place', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(
        itemsResponse([
          {'Id': 't1', 'Name': 'So What', 'Type': 'Audio'},
          {'Id': 'm1', 'Name': 'Interstellar', 'Type': 'Movie'},
          {'Id': 't2', 'Name': 'Flamenco Sketches', 'Type': 'Audio'},
        ]),
      ),
    );

    final result = await _repository(adapter).tracks(_playlistId);

    final page = result.valueOrNull!;
    expect(page.items, hasLength(2));
    expect(page.unavailable.single.id, 'm1');
    // The playlist still accounts for all three entries.
    expect(page.consumed, 3);
  });

  test('narrows playlists by a search term server-side', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    await _repository(adapter).playlists(searchTerm: 'road trip');

    final query = adapter.requests.single.queryParameters;
    expect(query['searchTerm'], 'road trip');
    expect(query['includeItemTypes'], 'Playlist');
  });

  group('addTracks (v0.1.6)', () {
    test('appends every track id to the playlist', () async {
      final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));

      final result = await _repository(adapter).addTracks(_playlistId, const [
        MediaId(serverId: 'server-1', itemId: 't1'),
        MediaId(serverId: 'server-1', itemId: 't2'),
      ]);

      expect(result.isOk, isTrue);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/Playlists/pl-1/Items');
      expect(request.queryParameters['ids'], 't1,t2');
    });

    test('does nothing for an empty track list', () async {
      final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));

      final result = await _repository(adapter).addTracks(_playlistId, []);

      expect(result.isOk, isTrue);
      expect(adapter.callCount, isZero);
    });
  });
}
