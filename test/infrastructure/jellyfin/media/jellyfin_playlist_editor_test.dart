import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinPlaylistEditor.dart';

import '../../../support/FakeDioAdapter.dart';
import '../../../support/FakeSessionContext.dart';

const _playlistId = MediaId(serverId: 'server-1', itemId: 'pl-1');
const _trackA = MediaId(serverId: 'server-1', itemId: 't-a');
const _trackB = MediaId(serverId: 'server-1', itemId: 't-b');
const _otherServerTrack = MediaId(serverId: 'server-2', itemId: 't-x');

JellyfinPlaylistEditor _editor(FakeDioAdapter adapter) =>
    JellyfinPlaylistEditor(testMediaApi(adapter));

void main() {
  test('creates a playlist, seeded with resolved track ids', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({'Id': 'new-pl'}),
    );

    final result = await _editor(
      adapter,
    ).create(name: 'Road Trip', trackIds: [_trackA, _trackB]);

    expect(result.valueOrNull, const MediaId(serverId: 'server-1', itemId: 'new-pl'));
    final request = adapter.requests.single;
    expect(request.path, '/Playlists');
    expect(request.method, 'POST');
    expect(request.queryParameters['name'], 'Road Trip');
    expect(request.queryParameters['ids'], 't-a,t-b');
  });

  test('refuses to seed a playlist with another server\'s track', () async {
    final adapter = FakeDioAdapter((_) async => jsonResponseBody(const {}));

    final result = await _editor(
      adapter,
    ).create(name: 'Road Trip', trackIds: [_otherServerTrack]);

    expect(result.isErr, isTrue);
    expect(adapter.requests, isEmpty);
  });

  test('renames without touching the playlist contents', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(const {}, statusCode: 204),
    );

    final result = await _editor(adapter).rename(_playlistId, 'New Name');

    expect(result.isOk, isTrue);
    final request = adapter.requests.single;
    expect(request.path, '/Playlists/pl-1');
    expect(request.method, 'POST');
    expect(request.data, {'Name': 'New Name'});
  });

  test('deletes a playlist through the generic item route', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(const {}, statusCode: 204),
    );

    await _editor(adapter).delete(_playlistId);

    final request = adapter.requests.single;
    expect(request.path, '/Items/pl-1');
    expect(request.method, 'DELETE');
  });

  test('appends tracks in order', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(const {}, statusCode: 204),
    );

    await _editor(adapter).addTracks(_playlistId, [_trackA, _trackB]);

    final request = adapter.requests.single;
    expect(request.path, '/Playlists/pl-1/Items');
    expect(request.method, 'POST');
    expect(request.queryParameters['ids'], 't-a,t-b');
  });

  test('batches a bulk add past the single-request limit', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(const {}, statusCode: 204),
    );
    final ids = List.generate(
      250,
      (i) => MediaId(serverId: 'server-1', itemId: 't$i'),
    );

    final result = await _editor(adapter).addTracks(_playlistId, ids);

    expect(result.isOk, isTrue);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests[0].queryParameters['ids'], hasLength(greaterThan(0)));
  });

  test('removes entries by their own entry id, not a track id', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(const {}, statusCode: 204),
    );

    await _editor(adapter).removeEntries(_playlistId, ['entry-1', 'entry-2']);

    final request = adapter.requests.single;
    expect(request.path, '/Playlists/pl-1/Items');
    expect(request.method, 'DELETE');
    expect(request.queryParameters['entryIds'], 'entry-1,entry-2');
  });

  test('does nothing for an empty removal', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(const {}, statusCode: 204),
    );

    await _editor(adapter).removeEntries(_playlistId, const []);

    expect(adapter.requests, isEmpty);
  });

  test('moves an entry to its new index', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(const {}, statusCode: 204),
    );

    await _editor(
      adapter,
    ).moveEntry(_playlistId, entryId: 'entry-1', newIndex: 3);

    final request = adapter.requests.single;
    expect(request.path, '/Playlists/pl-1/Items/entry-1/Move/3');
    expect(request.method, 'POST');
  });
}
