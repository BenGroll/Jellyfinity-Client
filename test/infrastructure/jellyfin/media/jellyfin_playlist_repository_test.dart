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

  group('playlist rows carry the playlist entry id (v0.1.2)', () {
    test('a track read through a playlist knows its own row', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {
              'Id': 't1',
              'Name': 'So What',
              'Type': 'Audio',
              'PlaylistItemId': 'entry-a',
            },
          ]),
        ),
      );

      final result = await _repository(adapter).tracks(_playlistId);

      final track = result.valueOrNull!.items.single;
      expect(track, isA<PlaylistTrack>());
      expect((track as PlaylistTrack).entryId, 'entry-a');
    });

    test('the same track listed twice is two separate rows', () async {
      // The reason removal is keyed on the entry rather than the track:
      // "remove So What" would not say which of these two the user meant.
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {
              'Id': 't1',
              'Name': 'So What',
              'Type': 'Audio',
              'PlaylistItemId': 'entry-a',
            },
            {
              'Id': 't1',
              'Name': 'So What',
              'Type': 'Audio',
              'PlaylistItemId': 'entry-b',
            },
          ]),
        ),
      );

      final result = await _repository(adapter).tracks(_playlistId);

      final rows = result.valueOrNull!.items.cast<PlaylistTrack>();
      expect(rows.map((row) => row.entryId), ['entry-a', 'entry-b']);
      expect(rows.first.id, rows.last.id);
    });

    test('a row the server gave no entry id for is still playable', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {'Id': 't1', 'Name': 'So What', 'Type': 'Audio'},
          ]),
        ),
      );

      final result = await _repository(adapter).tracks(_playlistId);

      final track = result.valueOrNull!.items.single;
      expect(track.name, 'So What');
      // Not editable, but present — dropping it would lose a song from
      // the list the user built.
      expect(track, isNot(isA<PlaylistTrack>()));
    });
  });

  group('curation (v0.1.2)', () {
    test('creates a playlist and answers with where it went', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody({'Id': 'pl-new'}),
      );

      final result = await _repository(adapter).create('Roadtrip');

      expect(
        result.valueOrNull,
        const MediaId(serverId: 'server-1', itemId: 'pl-new'),
      );
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/Playlists');
      final body = request.data as Map<String, dynamic>;
      expect(body['Name'], 'Roadtrip');
      // Without an explicit media type an empty playlist comes out
      // untyped and then never appears in the music playlist query.
      expect(body['MediaType'], 'Audio');
      expect(body['Ids'], isEmpty);
    });

    test('seeds a new playlist with the tracks it was given', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody({'Id': 'pl-new'}),
      );

      await _repository(adapter).create(
        'Roadtrip',
        trackIds: const [
          MediaId(serverId: 'server-1', itemId: 't1'),
          MediaId(serverId: 'server-1', itemId: 't2'),
        ],
      );

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['Ids'], ['t1', 't2']);
    });

    test(
      'refuses to seed from a different server rather than drop it',
      () async {
        final adapter = FakeDioAdapter(
          (_) async => jsonResponseBody({'Id': 'pl-new'}),
        );

        final result = await _repository(adapter).create(
          'Roadtrip',
          trackIds: const [MediaId(serverId: 'other-server', itemId: 't1')],
        );

        expect(result.isErr, isTrue);
        // Nothing was created: a playlist quietly missing the song the user
        // built it around is worse than being told it could not be.
        expect(adapter.callCount, isZero);
      },
    );

    test('a create the server answered without an id is a failure', () async {
      final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));

      final result = await _repository(adapter).create('Roadtrip');

      expect(result.isErr, isTrue);
    });

    test('renames without touching membership', () async {
      final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));

      final result = await _repository(adapter).rename(_playlistId, 'Evening');

      expect(result.isOk, isTrue);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/Playlists/pl-1');
      final body = request.data as Map<String, dynamic>;
      expect(body['Name'], 'Evening');
      // Jellyfin applies only the fields the body carries, so sending no
      // Ids is what leaves the playlist's contents alone.
      expect(body.containsKey('Ids'), isFalse);
    });

    test('deletes the playlist as the library item it is', () async {
      final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));

      final result = await _repository(adapter).delete(_playlistId);

      expect(result.isOk, isTrue);
      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/Items/pl-1');
    });

    test('removes rows by entry id, not by track id', () async {
      final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));

      final result = await _repository(
        adapter,
      ).removeEntries(_playlistId, const ['entry-a', 'entry-b']);

      expect(result.isOk, isTrue);
      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/Playlists/pl-1/Items');
      expect(request.queryParameters['entryIds'], 'entry-a,entry-b');
    });

    test('removing nothing asks the server nothing', () async {
      final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));

      final result = await _repository(adapter).removeEntries(_playlistId, []);

      expect(result.isOk, isTrue);
      expect(adapter.callCount, isZero);
    });

    test('a playlist on another server is refused, not misdirected', () async {
      final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));
      const elsewhere = MediaId(serverId: 'other-server', itemId: 'pl-9');

      expect((await _repository(adapter).rename(elsewhere, 'x')).isErr, isTrue);
      expect((await _repository(adapter).delete(elsewhere)).isErr, isTrue);
      expect(adapter.callCount, isZero);
    });
  });
}
