import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/music/presentation/detail/media_detail_cubit.dart';
import 'package:jellyfinity/features/music/presentation/detail/PlaylistDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';
import 'package:jellyfinity/features/music/presentation/widgets/music_rows.dart';

import '../../support/music_fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/pump_app.dart';

/// Curating a playlist from its own page — the create/rename/delete/remove
/// actions v0.1.2 specified and v0.3.0 finally shipped.

Future<FakePlaylistRepository> _pumpPlaylist(
  WidgetTester tester, {
  required List<Track> tracks,
}) async {
  final playlists = FakePlaylistRepository()..trackList = tracks;
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
}
