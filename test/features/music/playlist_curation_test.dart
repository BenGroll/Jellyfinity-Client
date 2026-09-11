import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/music/presentation/detail/media_detail_cubit.dart';
import 'package:jellyfinity/features/music/presentation/detail/PlaylistDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';
import 'package:jellyfinity/features/music/presentation/widgets/music_rows.dart';

import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/domain/playback/QueueOrigin.dart';

import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/pump_app.dart';

/// Curating a playlist from its own page — the create/rename/delete/remove
/// actions v0.1.2 specified and v0.3.0 finally shipped.

Future<FakePlaylistRepository> _pumpPlaylist(
  WidgetTester tester, {
  required List<Track> tracks,
  List<UnavailableItem> unavailable = const [],
  PageSource source = PageSource.server,
  PlaybackCubit? playback,
}) async {
  final playlists = FakePlaylistRepository()
    ..trackList = tracks
    ..unavailable = unavailable
    ..source = source;
  final metadata = FakeMediaMetadataRepository()
    ..items = [testPlaylist('pl1', name: 'Late Night')];
  registerMusicCubits(
    music: FakeMusicLibraryRepository(),
    playlists: playlists,
    metadata: metadata,
  );

  await pumpThemed(
    tester,
    PlaylistDetailPage(
      playlistId: mediaId('pl1'),
      detail: PlaylistDetailCubit(metadata, FakeOfflineMode()),
      tracks: PlaylistTracksCubit(playlists, FakeOfflineMode()),
    ),
    playback: playback,
  );
  await tester.pumpAndSettle();
  return playlists;
}

/// Opens the app bar's playlist menu. By tooltip, because the playback
/// actions row and every track row carry the same overflow icon.
Future<void> _openPlaylistMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Playlist options'));
  await tester.pumpAndSettle();
}

/// Opens the overflow of the track row at [index].
Future<void> _openRowMenu(WidgetTester tester, int index) async {
  await tester.tap(
    find
        .descendant(
          of: find.byType(TrackRow),
          matching: find.byIcon(Icons.more_vert_rounded),
        )
        .at(index),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  group('renaming', () {
    testWidgets('sends the new name to the server', (tester) async {
      final playlists = await _pumpPlaylist(tester, tracks: []);

      await _openPlaylistMenu(tester);
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Evening');
      await tester.tap(find.widgetWithText(TextButton, 'Rename'));
      await tester.pumpAndSettle();

      expect(playlists.renameCalls.single.name, 'Evening');
      expect(playlists.renameCalls.single.playlistId, mediaId('pl1'));
    });

    testWidgets('starts from the name the playlist already has', (
      tester,
    ) async {
      await _pumpPlaylist(tester, tracks: []);

      await _openPlaylistMenu(tester);
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'Late Night');
    });

    testWidgets('will not accept a blank name', (tester) async {
      final playlists = await _pumpPlaylist(tester, tracks: []);

      await _openPlaylistMenu(tester);
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      // A playlist with no name could not be found again, so the button
      // is unusable rather than the request being sent and rejected.
      final confirm = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Rename'),
      );
      expect(confirm.onPressed, isNull);
      expect(playlists.renameCalls, isEmpty);
    });

    testWidgets('backing out changes nothing', (tester) async {
      final playlists = await _pumpPlaylist(tester, tracks: []);

      await _openPlaylistMenu(tester);
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(playlists.renameCalls, isEmpty);
    });
  });

  group('deleting', () {
    testWidgets('asks first, and says the songs stay', (tester) async {
      final playlists = await _pumpPlaylist(tester, tracks: []);

      await _openPlaylistMenu(tester);
      await tester.tap(find.text('Delete playlist'));
      await tester.pumpAndSettle();

      expect(find.textContaining('songs in it stay'), findsOneWidget);
      expect(playlists.deleteCalls, isEmpty);
    });

    testWidgets('deletes once confirmed', (tester) async {
      final playlists = await _pumpPlaylist(tester, tracks: []);

      await _openPlaylistMenu(tester);
      await tester.tap(find.text('Delete playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(playlists.deleteCalls, [mediaId('pl1')]);
    });

    testWidgets('a declined confirmation deletes nothing', (tester) async {
      final playlists = await _pumpPlaylist(tester, tracks: []);

      await _openPlaylistMenu(tester);
      await tester.tap(find.text('Delete playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(playlists.deleteCalls, isEmpty);
    });
  });

  group('removing a row', () {
    testWidgets('removes the entry, not the track', (tester) async {
      final playlists = await _pumpPlaylist(
        tester,
        tracks: [testPlaylistTrack('t1', entryId: 'entry-a')],
      );

      await _openRowMenu(tester, 0);
      await tester.tap(find.text('Remove from this playlist'));
      await tester.pumpAndSettle();

      final call = playlists.removeEntryCalls.single;
      expect(call.playlistId, mediaId('pl1'));
      // The entry id, so the right one of several appearances goes.
      expect(call.entryIds, ['entry-a']);
    });

    testWidgets('picks the row that was tapped, not the first match', (
      tester,
    ) async {
      // The same song listed twice — the case that makes removing by
      // track id ambiguous.
      final playlists = await _pumpPlaylist(
        tester,
        tracks: [
          testPlaylistTrack('t1', entryId: 'entry-a'),
          testPlaylistTrack('t1', entryId: 'entry-b'),
        ],
      );

      await _openRowMenu(tester, 1);
      await tester.tap(find.text('Remove from this playlist'));
      await tester.pumpAndSettle();

      expect(playlists.removeEntryCalls.single.entryIds, ['entry-b']);
    });

    testWidgets('is not offered for a row read from the saved copy', (
      tester,
    ) async {
      // A plain Track, as the offline cache and download snapshots
      // produce: no entry id, so nothing to remove by — and editing needs
      // the server regardless.
      await _pumpPlaylist(tester, tracks: [testTrack('t1')]);

      await _openRowMenu(tester, 0);

      expect(find.text('Remove from this playlist'), findsNothing);
      // The queue actions are still there; only the server edit is gone.
      expect(find.text('Play Next'), findsOneWidget);
    });

    testWidgets('a refused removal says so and keeps the row', (tester) async {
      final playlists = await _pumpPlaylist(
        tester,
        tracks: [testPlaylistTrack('t1', name: 'So What')],
      );
      playlists.writeFailure = const RecoverableFailure('Server unreachable.');

      await _openRowMenu(tester, 0);
      await tester.tap(find.text('Remove from this playlist'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not remove "So What"'), findsOneWidget);
      expect(find.text('So What'), findsWidgets);
    });
  });

  group('reorder (v0.4.2)', () {
    testWidgets('numbers rows the way the playlist does', (tester) async {
      // A film between two songs. Numbering the rows 1 and 2 would tell
      // the user their playlist is something it is not.
      await _pumpPlaylist(
        tester,
        tracks: [
          testPlaylistTrack('t1', name: 'So What', position: 0),
          testPlaylistTrack('t2', name: 'Blue in Green', position: 2),
        ],
        unavailable: const [
          UnavailableItem(
            id: 'm1',
            reason: 'This entry is not an available song.',
            position: 1,
          ),
        ],
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // The unreadable entry is listed at its own number, not hidden and
      // not counted as one of the songs.
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(UnavailableRow), findsOneWidget);
    });

    testWidgets('moves a row from the menu, without a drag', (tester) async {
      // The Windows path, and the accessible path everywhere: pointer or
      // keyboard, no press-and-hold.
      final playlists = await _pumpPlaylist(
        tester,
        tracks: [
          testPlaylistTrack('t1', position: 0),
          testPlaylistTrack('t2', position: 2),
        ],
        unavailable: const [
          UnavailableItem(id: 'm1', reason: 'Not a song.', position: 1),
        ],
      );

      await _openRowMenu(tester, 0);
      await tester.tap(find.text('Move down'));
      await tester.pumpAndSettle();

      expect(playlists.moveCalls.single.entryId, 'entry-t1');
      // Entry 2, past the entry Jellyfinity cannot read.
      expect(playlists.moveCalls.single.newIndex, 2);
    });

    testWidgets('the ends of the list offer only the move that exists', (
      tester,
    ) async {
      await _pumpPlaylist(
        tester,
        tracks: [
          testPlaylistTrack('t1', position: 0),
          testPlaylistTrack('t2', position: 1),
        ],
      );

      await _openRowMenu(tester, 0);
      expect(find.text('Move up'), findsNothing);
      expect(find.text('Move down'), findsOneWidget);
    });

    testWidgets('a drag handle appears only where the playlist can be '
        'edited', (tester) async {
      await _pumpPlaylist(
        tester,
        tracks: [
          testPlaylistTrack('t1', position: 0),
          testPlaylistTrack('t2', position: 1),
        ],
      );

      expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(2));
    });

    testWidgets('a saved copy is playable but not rearrangeable', (
      tester,
    ) async {
      await _pumpPlaylist(
        tester,
        tracks: [
          testPlaylistTrack('t1', entryId: null, position: 0),
          testPlaylistTrack('t2', entryId: null, position: 1),
        ],
        source: PageSource.cache,
      );

      expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
      await _openRowMenu(tester, 0);
      expect(find.text('Move down'), findsNothing);
      expect(find.text('Play Next'), findsOneWidget);
    });

    testWidgets('a refused move says so', (tester) async {
      final playlists = await _pumpPlaylist(
        tester,
        tracks: [
          testPlaylistTrack('t1', position: 0),
          testPlaylistTrack('t2', position: 1),
        ],
      );
      playlists.moveFailure = const RecoverableFailure('Server unreachable.');

      await _openRowMenu(tester, 0);
      await tester.tap(find.text('Move down'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not move that song'), findsOneWidget);
    });
  });

  group('the playlist session (v0.4.2)', () {
    testWidgets('offers to carry on the queue this playlist started', (
      tester,
    ) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      await playback.playNow(
        [testTrack('t1', name: 'So What')],
        startIndex: 0,
        origin: QueueOrigin.playlist(
          playlistId: mediaId('pl1'),
          name: 'Late Night',
        ),
      );
      // Paused, which is the state a queue is in when the listener comes
      // back to the playlist it was started from.
      await playback.togglePlayPause();

      await _pumpPlaylist(
        tester,
        tracks: [testPlaylistTrack('t1', name: 'So What', position: 0)],
        playback: playback,
      );

      expect(find.textContaining('Continue "So What"'), findsOneWidget);
    });

    testWidgets('says nothing when the queue came from somewhere else', (
      tester,
    ) async {
      // The same song, playing, but not from this playlist. A song
      // appearing in a list is not a session in it.
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      await playback.playNow([testTrack('t1', name: 'So What')], startIndex: 0);
      await playback.togglePlayPause();

      await _pumpPlaylist(
        tester,
        tracks: [testPlaylistTrack('t1', name: 'So What', position: 0)],
        playback: playback,
      );

      expect(find.textContaining('Continue'), findsNothing);
    });
  });
}
