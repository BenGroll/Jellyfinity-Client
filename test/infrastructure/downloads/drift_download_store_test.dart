import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/downloads/downloads.dart';
import 'package:jellyfinity/domain/media/artist.dart';
import 'package:jellyfinity/infrastructure/downloads/DriftDownloadStore.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';

import '../../support/music_fakes.dart';
import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftDownloadStore store;

  setUp(() {
    db = newTestDatabase();
    store = DriftDownloadStore(db);
  });

  tearDown(() => db.close());

  TrackDownload record(
    String item, {
    DownloadState state = DownloadState.queued,
    Set<DownloadOwner>? owners,
    DateTime? requestedAt,
  }) {
    final track = testTrack(item, albumId: 'album-1');
    return TrackDownload.requested(
      track,
      owner: DownloadOwner.track(track.id),
      requestedAt: requestedAt ?? DateTime.utc(2026, 1, 1),
    ).copyWith(state: state, owners: owners);
  }

  test('a record round-trips through save and find', () async {
    final original = record(
      'track-1',
      state: DownloadState.completed,
    ).copyWith(receivedBytes: 500, totalBytes: 500);

    await store.save(original);
    final found = await store.find(original.id);

    expect(found.valueOrNull, original);
  });

  test('find answers null for an id never requested', () async {
    final found = await store.find(mediaId('missing'));
    expect(found.valueOrNull, isNull);
  });

  test('all() orders by request time, not by write order', () async {
    final first = record('a', requestedAt: DateTime.utc(2026, 1, 1));
    final second = record('b', requestedAt: DateTime.utc(2026, 1, 2));

    // Written in reverse order deliberately.
    await store.save(second);
    await store.save(first);

    final all = await store.all();
    expect(all.valueOrNull?.map((r) => r.id.itemId).toList(), ['a', 'b']);
  });

  test('save replaces an existing record for the same id', () async {
    final original = record('track-1', state: DownloadState.queued);
    await store.save(original);

    final updated = original.copyWith(state: DownloadState.completed);
    await store.save(updated);

    final all = await store.all();
    expect(all.valueOrNull?.length, 1);
    expect(all.valueOrNull?.single.state, DownloadState.completed);
  });

  test('delete removes both the record and its owners', () async {
    final owner = DownloadOwner.album(mediaId('album-1'));
    final original = record('track-1', owners: {owner});
    await store.save(original);

    await store.delete(original.id);

    expect((await store.find(original.id)).valueOrNull, isNull);
    expect((await store.ownedBy(owner)).valueOrNull, isEmpty);
  });

  test('rewriting the owner set replaces it rather than appending', () async {
    final trackOwner = DownloadOwner.track(mediaId('track-1'));
    final albumOwner = DownloadOwner.album(mediaId('album-1'));
    final original = record('track-1', owners: {trackOwner});
    await store.save(original);

    await store.save(original.copyWith(owners: {albumOwner}));

    expect((await store.ownedBy(trackOwner)).valueOrNull, isEmpty);
    expect((await store.ownedBy(albumOwner)).valueOrNull, [original.id]);
  });

  test('ownedBy answers every track one collection asked for', () async {
    final albumOwner = DownloadOwner.album(mediaId('album-1'));
    final a = record('a', owners: {albumOwner});
    final b = record('b', owners: {albumOwner});
    final unrelated = record(
      'c',
      owners: {DownloadOwner.album(mediaId('album-2'))},
    );
    await store.save(a);
    await store.save(b);
    await store.save(unrelated);

    final owned = (await store.ownedBy(albumOwner)).valueOrNull!;
    expect(owned.toSet(), {a.id, b.id});
  });

  test('preserves artist credits, album, and track/disc numbers', () async {
    final original = TrackDownload.requested(
      testTrack('track-1', albumId: 'album-1', trackNumber: 4),
      owner: DownloadOwner.track(mediaId('track-1')),
      requestedAt: DateTime.utc(2026),
    ).copyWith(state: DownloadState.completed);

    await store.save(original);
    final found = (await store.find(original.id)).valueOrNull!;

    expect(found.artists, [const ArtistRef(name: 'Miles Davis')]);
    expect(found.albumId, original.albumId);
    expect(found.albumName, original.albumName);
    expect(found.trackNumber, 4);
  });

  test('preserves a failure reason only while the state is failed', () async {
    final failed = record(
      'track-1',
      state: DownloadState.failed,
    ).copyWith(failureReason: DownloadFailureReason.network);
    await store.save(failed);

    final found = (await store.find(failed.id)).valueOrNull!;
    expect(found.failureReason, DownloadFailureReason.network);

    // A stale reason from an earlier failure must not resurface once the
    // download is queued again.
    final retried = found.copyWith(
      state: DownloadState.queued,
      clearFailureReason: true,
    );
    await store.save(retried);
    final reFound = (await store.find(failed.id)).valueOrNull!;
    expect(reFound.failureReason, isNull);
  });

  group('playlist membership snapshots (v0.2.1)', () {
    final playlist = mediaId('pl-1');

    test('round-trips an ordered snapshot', () async {
      final members = [
        (position: 0, trackId: mediaId('t1')),
        (position: 1, trackId: mediaId('t2')),
        (position: 2, trackId: mediaId('t3')),
      ];

      await store.savePlaylistMembers(playlist, members);

      expect((await store.playlistMembers(playlist)).valueOrNull, members);
    });

    test('replaces the snapshot rather than appending to it', () async {
      await store.savePlaylistMembers(playlist, [
        (position: 0, trackId: mediaId('t1')),
        (position: 1, trackId: mediaId('t2')),
      ]);
      await store.savePlaylistMembers(playlist, [
        (position: 0, trackId: mediaId('t2')),
      ]);

      final members = (await store.playlistMembers(playlist)).valueOrNull!;
      expect(members.map((m) => m.trackId.itemId), ['t2']);
    });

    test('an empty snapshot clears the playlist', () async {
      await store.savePlaylistMembers(playlist, [
        (position: 0, trackId: mediaId('t1')),
      ]);
      await store.savePlaylistMembers(playlist, const []);

      expect((await store.playlistMembers(playlist)).valueOrNull, isEmpty);
    });

    test('allPlaylistMembers groups every snapshot by playlist', () async {
      await store.savePlaylistMembers(playlist, [
        (position: 0, trackId: mediaId('t1')),
      ]);
      await store.savePlaylistMembers(mediaId('pl-2'), [
        (position: 0, trackId: mediaId('t9')),
        (position: 1, trackId: mediaId('t8')),
      ]);

      final all = (await store.allPlaylistMembers()).valueOrNull!;
      expect(all[playlist], hasLength(1));
      expect(all[mediaId('pl-2')]!.map((m) => m.trackId.itemId), ['t9', 't8']);
    });

    test('deletePlaylistMembers forgets one snapshot', () async {
      await store.savePlaylistMembers(playlist, [
        (position: 0, trackId: mediaId('t1')),
      ]);

      await store.deletePlaylistMembers(playlist);

      expect((await store.playlistMembers(playlist)).valueOrNull, isEmpty);
    });
  });
}
