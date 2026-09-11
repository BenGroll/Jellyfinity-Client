import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart';

import '../../support/music_fakes.dart';
import '../../support/offline_fakes.dart';

/// Reordering a playlist (v0.4.2) — the half of v0.1.2 ADR-0024 left
/// open because the index the screen can see is not the index the server
/// counts in.
///
/// Every case here is that discrepancy: a playlist holding something
/// Jellyfinity cannot read, a song listed twice, a server that says no,
/// and a saved copy that cannot be edited at all.

PlaylistTracksCubit _cubit(
  FakePlaylistRepository playlists, {
  FakeOfflineMode? offline,
}) {
  final cubit = PlaylistTracksCubit(playlists, offline ?? FakeOfflineMode());
  addTearDown(cubit.close);
  return cubit;
}

/// A playlist whose second entry is a film: three entries, two readable
/// rows at positions 0 and 2.
FakePlaylistRepository _withAFilmInTheMiddle() => FakePlaylistRepository()
  ..trackList = [
    testPlaylistTrack('t1', name: 'So What', position: 0),
    testPlaylistTrack('t2', name: 'Blue in Green', position: 2),
  ]
  ..unavailable = const [
    UnavailableItem(
      id: 'm1',
      reason: 'This entry is not an available song.',
      position: 1,
    ),
  ];

void main() {
  test('moves a row to the index the server counts in, not the one on '
      'screen', () async {
    final playlists = _withAFilmInTheMiddle();
    final cubit = _cubit(playlists);
    await cubit.forPlaylist(mediaId('pl1'));

    // Drag the first row below the second. On screen that is index 1; in
    // the playlist the destination is entry 2, because the film in
    // between still occupies entry 1.
    final failure = await cubit.moveEntry(from: 0, to: 1);

    expect(failure, isNull);
    expect(playlists.moveCalls.single.entryId, 'entry-t1');
    expect(playlists.moveCalls.single.newIndex, 2);
  });

  test('moving up lands on the displaced row, film and all', () async {
    final playlists = _withAFilmInTheMiddle();
    final cubit = _cubit(playlists);
    await cubit.forPlaylist(mediaId('pl1'));

    final failure = await cubit.moveEntry(from: 1, to: 0);

    expect(failure, isNull);
    expect(playlists.moveCalls.single.entryId, 'entry-t2');
    // Where the row it displaced sits — entry 0 — so the film stays
    // exactly where the user left it.
    expect(playlists.moveCalls.single.newIndex, 0);
  });

  test('a song listed twice moves the appearance that was dragged', () async {
    final playlists = FakePlaylistRepository()
      ..trackList = [
        testPlaylistTrack('t1', entryId: 'entry-a', position: 0),
        testPlaylistTrack('t2', position: 1),
        testPlaylistTrack('t1', entryId: 'entry-b', position: 2),
      ];
    final cubit = _cubit(playlists);
    await cubit.forPlaylist(mediaId('pl1'));

    await cubit.moveEntry(from: 2, to: 0);

    // The second appearance, named by its own entry id. By track id the
    // request would be ambiguous, and by position it would be a guess.
    expect(playlists.moveCalls.single.entryId, 'entry-b');
    expect(playlists.moveCalls.single.newIndex, 0);
  });

  test('the list re-reads itself after a move so the numbering is the '
      "server's", () async {
    final playlists = _withAFilmInTheMiddle();
    final cubit = _cubit(playlists);
    await cubit.forPlaylist(mediaId('pl1'));
    final readsBefore = playlists.trackReads;

    await cubit.moveEntry(from: 0, to: 1);

    expect(playlists.trackReads, greaterThan(readsBefore));
  });

  test('a rejected move puts the list back', () async {
    final playlists = _withAFilmInTheMiddle()
      ..moveFailure = const RecoverableFailure('The server said no.');
    final cubit = _cubit(playlists);
    await cubit.forPlaylist(mediaId('pl1'));

    final failure = await cubit.moveEntry(from: 0, to: 1);

    expect(failure?.message, 'The server said no.');
    // The screen shows what the playlist actually is, not what the drag
    // hoped it would be.
    expect(cubit.state.items.map((row) => row.name), [
      'So What',
      'Blue in Green',
    ]);
  });

  test('a saved copy cannot be rearranged', () async {
    final playlists = FakePlaylistRepository()
      ..source = PageSource.cache
      ..trackList = [
        // Offline rows know where they sit and have no entry id — there
        // is nothing to name in a write (ADR-0024).
        testPlaylistTrack('t1', entryId: null, position: 0),
        testPlaylistTrack('t2', entryId: null, position: 1),
      ];
    final cubit = _cubit(playlists);
    await cubit.forPlaylist(mediaId('pl1'));

    final failure = await cubit.moveEntry(from: 0, to: 1);

    expect(failure, isNotNull);
    expect(playlists.moveCalls, isEmpty);
  });

  test('a move that goes nowhere asks the server nothing', () async {
    final playlists = _withAFilmInTheMiddle();
    final cubit = _cubit(playlists);
    await cubit.forPlaylist(mediaId('pl1'));

    expect(await cubit.moveEntry(from: 1, to: 1), isNull);
    expect(await cubit.moveEntry(from: 0, to: 7), isNull);

    expect(playlists.moveCalls, isEmpty);
  });
}
