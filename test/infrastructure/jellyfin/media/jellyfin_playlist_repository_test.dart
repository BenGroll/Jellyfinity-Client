import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinPlaylistRepository.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/jellyfin_media_api.dart';

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

  test('reads an ownerless playlist through the generic item listing when '
      'the dedicated route forbids it', () async {
    // A playlist that predates Jellyfin's per-user ownership model has
    // no matching OwnerUserId, so /Playlists/{id}/Items forbids
    // everyone — even ChildCount comes back 0 for the same reason.
    final adapter = FakeDioAdapter((options) async {
      if (options.path == '/Playlists/pl-1/Items') {
        return jsonResponseBody({}, statusCode: 403);
      }
      return jsonResponseBody(
        itemsResponse([
          {'Id': 't1', 'Name': 'So What', 'Type': 'Audio'},
        ], totalRecordCount: 12),
      );
    });

    final result = await _repository(adapter).tracks(_playlistId);

    final page = result.valueOrNull!;
    expect(page.items.single.name, 'So What');
    expect(page.totalCount, 12);
    final fallback = adapter.requests.last;
    expect(fallback.path, JellyfinMediaApi.itemsPath);
    expect(fallback.queryParameters['parentId'], 'pl-1');
  });

  test('recovers a playlist\'s real count when the server misreports it as '
      'empty', () async {
    final adapter = FakeDioAdapter((options) async {
      if (options.path == '/Playlists/pl-1/Items') {
        return jsonResponseBody({}, statusCode: 403);
      }
      if (options.queryParameters['parentId'] == 'pl-1') {
        return jsonResponseBody(
          itemsResponse([
            {'Id': 't1', 'Name': 'So What', 'Type': 'Audio'},
          ], totalRecordCount: 12),
        );
      }
      return jsonResponseBody(
        itemsResponse([
          {
            'Id': 'pl-1',
            'Name': 'Ownerless Mix',
            'Type': 'Playlist',
            'ChildCount': 0,
          },
        ]),
      );
    });

    final result = await _repository(adapter).playlists();

    final playlist = result.valueOrNull!.items.single;
    expect(playlist.name, 'Ownerless Mix');
    expect(playlist.itemCount, 12);
  });

  test('leaves a genuinely empty playlist alone', () async {
    final adapter = FakeDioAdapter((options) async {
      if (options.path == '/Playlists/pl-1/Items' ||
          options.queryParameters['parentId'] == 'pl-1') {
        return jsonResponseBody(itemsResponse(const []));
      }
      return jsonResponseBody(
        itemsResponse([
          {
            'Id': 'pl-1',
            'Name': 'Empty Playlist',
            'Type': 'Playlist',
            'ChildCount': 0,
          },
        ]),
      );
    });

    final result = await _repository(adapter).playlists();

    final playlist = result.valueOrNull!.items.single;
    expect(playlist.itemCount, 0);
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
}
