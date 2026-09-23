import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/music/presentation/detail/PlaylistDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/detail/media_detail_cubit.dart';
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';

import '../../../support/music_fakes.dart';
import '../../../support/offline_fakes.dart';
import '../../../support/pump_app.dart';

/// Bulk selection and playlist actions (v0.7.0), exercised through
/// `PlaylistDetailPage` — one of the required multi-select surfaces and
/// already wired for widget testing by `playlist_curation_test.dart`.

Future<FakePlaylistRepository> _pumpPlaylist(
  WidgetTester tester, {
  required List<Track> tracks,
  List<Playlist> pickerPlaylists = const [],
}) async {
  final playlists = FakePlaylistRepository()
    ..trackList = tracks
    ..playlistList = pickerPlaylists;
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

Future<void> _enterSelection(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Select songs'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  testWidgets('adds the checked songs in displayed order, not tap order', (
    tester,
  ) async {
    final playlists = await _pumpPlaylist(
      tester,
      tracks: [
        testPlaylistTrack('t1', name: 'So What', position: 0),
        testPlaylistTrack('t2', name: 'Blue in Green', position: 1),
      ],
      pickerPlaylists: [testPlaylist('pl2', name: 'Favorites Mix')],
    );

    await _enterSelection(tester);
    // Checked in reverse of how they are displayed.
    await tester.tap(find.text('Blue in Green'));
    await tester.pump();
    await tester.tap(find.text('So What'));
    await tester.pump();

    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Add to playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites Mix'));
    await tester.pumpAndSettle();

    expect(playlists.addTracksCalls, hasLength(1));
    expect(playlists.addTracksCalls.single.trackIds, [
      mediaId('t1'),
      mediaId('t2'),
    ]);
    expect(find.textContaining('Added 2 songs'), findsOneWidget);
    // Selection mode ends once the add completes.
    expect(find.text('Select songs'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('Cancel leaves selection mode without adding anything', (
    tester,
  ) async {
    final playlists = await _pumpPlaylist(
      tester,
      tracks: [testPlaylistTrack('t1', name: 'So What', position: 0)],
    );

    await _enterSelection(tester);
    await tester.tap(find.text('So What'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(playlists.addTracksCalls, isEmpty);
    // The row's ordinary tap handler is restored, not left wired to
    // toggling a selection that no longer exists.
    expect(find.byTooltip('Select songs'), findsOneWidget);
  });

  testWidgets(
    'Escape leaves selection mode instead of navigating away (D-pad-safe exit)',
    (tester) async {
      await _pumpPlaylist(
        tester,
        tracks: [testPlaylistTrack('t1', name: 'So What', position: 0)],
      );

      await _enterSelection(tester);
      await tester.tap(find.text('So What'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);

      // Same key a TV remote's back button and Android's system back both
      // resolve to; SelectionExitGuard binds all three to the same exit.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      // Still on the playlist page — Escape did not pop the route.
      expect(find.text('Late Night'), findsWidgets);
    },
  );

  testWidgets('an unavailable row cannot be checked', (tester) async {
    await _pumpPlaylist(
      tester,
      tracks: [
        testPlaylistTrack('t1', name: 'So What', position: 0),
        PlaylistTrack(
          position: 1,
          entryId: 'entry-t2',
          id: mediaId('t2'),
          name: 'Blue in Green',
          availability: MediaAvailability.remoteUnavailable,
        ),
      ],
    );

    await _enterSelection(tester);

    // One selectable row (So What) got a checkbox; the unavailable row
    // did not, so tapping it does not increment the count.
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    await tester.tap(find.text('Blue in Green'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('0 selected'), findsOneWidget);
  });

  testWidgets(
    'a row that goes unavailable after being checked is dropped from the add',
    (tester) async {
      final playlists = await _pumpPlaylist(
        tester,
        tracks: [
          testPlaylistTrack('t1', name: 'So What', position: 0),
          testPlaylistTrack('t2', name: 'Blue in Green', position: 1),
        ],
        pickerPlaylists: [testPlaylist('pl2', name: 'Favorites Mix')],
      );

      await _enterSelection(tester);
      await tester.tap(find.text('So What'));
      await tester.pump();
      await tester.tap(find.text('Blue in Green'));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);

      // The server drops "Blue in Green" between selecting it and adding
      // it — a refresh (the same trigger a real reconnect would fire)
      // reads the row as unavailable.
      playlists.trackList = [
        testPlaylistTrack('t1', name: 'So What', position: 0),
        PlaylistTrack(
          position: 1,
          entryId: 'entry-t2',
          id: mediaId('t2'),
          name: 'Blue in Green',
          availability: MediaAvailability.remoteUnavailable,
        ),
      ];
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();

      // Still checked internally, but no longer counted or shown as
      // selectable — the row's own checkbox is gone.
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Add to playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favorites Mix'));
      await tester.pumpAndSettle();

      expect(playlists.addTracksCalls, hasLength(1));
      expect(playlists.addTracksCalls.single.trackIds, [mediaId('t1')]);
      expect(
        find.textContaining('no longer available were skipped'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a failed add keeps the still-valid selection so the user can retry',
    (tester) async {
      final playlists = await _pumpPlaylist(
        tester,
        tracks: [testPlaylistTrack('t1', name: 'So What', position: 0)],
        pickerPlaylists: [testPlaylist('pl2', name: 'Favorites Mix')],
      );

      await _enterSelection(tester);
      await tester.tap(find.text('So What'));
      await tester.pump();

      await tester.tap(find.text('Add to playlist'));
      await tester.pumpAndSettle();
      // The picker has already read its playlist list; failing the
      // repository from here on only affects the add itself.
      playlists.failure = const RecoverableFailure('Connection lost');
      await tester.tap(find.text('Favorites Mix'));
      await tester.pumpAndSettle();

      expect(playlists.addTracksCalls, isEmpty);
      expect(find.textContaining('Could not add'), findsOneWidget);
      // Selection survives the failure — nothing was actually added.
      expect(find.text('1 selected'), findsOneWidget);
    },
  );
}
