import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/design/design.dart';
import 'package:jellyfinity/domain/media/media_availability.dart';
import 'package:jellyfinity/features/music/presentation/detail/AlbumDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/detail/media_detail_cubit.dart';
import 'package:jellyfinity/features/music/presentation/detail/PlaylistDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';
import 'package:jellyfinity/features/music/presentation/widgets/music_rows.dart';
import 'package:jellyfinity/features/music/presentation/widgets/music_skeletons.dart';

import '../../support/download_fakes.dart';
import '../../support/music_fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/pump_app.dart';

Future<void> _pumpAlbum(
  WidgetTester tester,
  FakeMusicLibraryRepository music,
) async {
  // The page owns these cubits and closes them; the test must not.
  await pumpThemed(
    tester,
    AlbumDetailPage(
      albumId: mediaId('al1'),
      detail: AlbumDetailCubit(music, FakeOfflineMode()),
      tracks: SongsCubit(
        music,
        FakeDownloadsLibrarySource(),
        FakeOfflineMode(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  testWidgets('shows the album while its tracks are still coming', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..albumList = [testAlbum('al1', name: 'Kind of Blue')]
      ..trackList = [testTrack('t1', name: 'So What', trackNumber: 1)]
      ..responseDelay = const Duration(milliseconds: 50);

    await _pumpAlbum(tester, music);
    // The header read is not delayed; the track window is.
    await tester.pump(const Duration(milliseconds: 20));

    // The header is up; the track list is still a skeleton.
    expect(find.text('Kind of Blue'), findsWidgets);
    expect(find.byType(MusicListSkeleton), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('So What'), findsOneWidget);
  });

  testWidgets('an album keeps its usable tracks and marks the rest', (
    tester,
  ) async {
    // CONTEXT.md's rule, on screen: eleven usable tracks and one clearly
    // marked, not a failed album.
    final music = FakeMusicLibraryRepository()
      ..albumList = [testAlbum('al1', name: 'Kind of Blue')]
      ..trackList = [
        testTrack('t1', name: 'So What', trackNumber: 1),
        testTrack('t2', name: 'Blue in Green', trackNumber: 2),
      ]
      ..unavailable = const [
        UnavailableItem(id: 't3', reason: 'This song is unavailable.'),
      ];

    await _pumpAlbum(tester, music);
    await tester.pumpAndSettle();

    expect(find.text('So What'), findsOneWidget);
    expect(find.text('Blue in Green'), findsOneWidget);
    // The taller v0.1.6 header (Shuffle/Play/overflow row) pushes the
    // trailing unavailable row past the default test viewport.
    await tester.scrollUntilVisible(find.byType(UnavailableRow), 300);
    expect(find.byType(UnavailableRow), findsOneWidget);
    expect(find.byType(ErrorStateView), findsNothing);
  });

  testWidgets('shows the facts an album header carries', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..albumList = [testAlbum('al1', name: 'Kind of Blue')]
      ..trackList = [testTrack('t1', trackNumber: 1)];

    await _pumpAlbum(tester, music);
    await tester.pumpAndSettle();

    expect(find.text('1959 · 5 songs'), findsOneWidget);
    // The credits line under the title (the track rows repeat it).
    expect(find.text('Miles Davis'), findsWidgets);
  });

  testWidgets('a missing album header does not take the tracks down', (
    tester,
  ) async {
    // The album item is gone but its tracks still answer: the screen
    // shows what it has rather than blanking.
    final music = FakeMusicLibraryRepository()
      ..trackList = [testTrack('t1', name: 'So What', trackNumber: 1)];

    await _pumpAlbum(tester, music);
    await tester.pumpAndSettle();

    expect(find.text('So What'), findsOneWidget);
    expect(find.byType(ErrorStateView), findsOneWidget);
  });

  testWidgets('numbers a playlist by its own order, gaps included', (
    tester,
  ) async {
    final playlists = FakePlaylistRepository()
      ..trackList = [
        testTrack('t1', name: 'So What'),
        testTrack('t2', name: 'Blue in Green'),
      ]
      ..unavailable = const [
        UnavailableItem(
          id: 'm1',
          reason: 'This entry is not an available song.',
        ),
      ];
    final metadata = FakeMediaMetadataRepository()
      ..items = [testPlaylist('pl1', name: 'Late Night')];

    await pumpThemed(
      tester,
      PlaylistDetailPage(
        playlistId: mediaId('pl1'),
        detail: PlaylistDetailCubit(metadata, FakeOfflineMode()),
        tracks: PlaylistTracksCubit(playlists, FakeOfflineMode()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Late Night'), findsWidgets);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    // The entry that is not a song still occupies its place.
    expect(find.byType(UnavailableRow), findsOneWidget);
  });

  testWidgets('an unreachable server on a detail screen offers a retry', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..failure = const RecoverableFailure('Could not reach the server.');

    await _pumpAlbum(tester, music);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorStateView), findsWidgets);
    expect(find.text('Try again'), findsWidgets);
  });

  testWidgets('downloads a whole playlist from its header (v0.2.1)', (
    tester,
  ) async {
    final playlists = FakePlaylistRepository()
      ..trackList = [
        testTrack('t1', name: 'So What'),
        testTrack('t2', name: 'Blue in Green'),
      ];
    final metadata = FakeMediaMetadataRepository()
      ..items = [testPlaylist('pl1', name: 'Late Night')];
    final store = InMemoryDownloadStore();
    final downloads = fakeDownloadsCubit(
      store: store,
      engine: FakeDownloadEngine(),
      playlists: playlists,
    );
    await downloads.restore();

    await pumpThemed(
      tester,
      PlaylistDetailPage(
        playlistId: mediaId('pl1'),
        detail: PlaylistDetailCubit(metadata, FakeOfflineMode()),
        tracks: PlaylistTracksCubit(playlists, FakeOfflineMode()),
      ),
      downloads: downloads,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Download playlist'));
    await tester.pumpAndSettle();

    expect(downloads.state.isPlaylistDownloaded(mediaId('pl1')), isTrue);
    expect(store.playlistSnapshots[mediaId('pl1')], hasLength(2));
    // The header now shows the honest aggregate summary.
    expect(find.textContaining('Downloaded'), findsWidgets);
  });

  testWidgets(
    'a partly-downloaded album offline shows one "not available" line '
    '(v0.2.3)',
    (tester) async {
      final music = FakeMusicLibraryRepository()
        ..albumList = [testAlbum('al1', name: 'Kind of Blue')]
        ..trackList = [testTrack('t1', name: 'So What', trackNumber: 1)]
        ..unavailable = const [
          UnavailableItem(id: 'g0', reason: offlineUnavailableReason),
          UnavailableItem(id: 'g1', reason: offlineUnavailableReason),
          UnavailableItem(id: 'g2', reason: offlineUnavailableReason),
        ];

      await _pumpAlbum(tester, music);
      await tester.pumpAndSettle();

      expect(find.text('So What'), findsOneWidget);
      expect(find.text('3 songs not available offline'), findsOneWidget);
      // Collapsed into the one line, not three rows.
      expect(find.byType(UnavailableRow), findsNothing);
    },
  );

  testWidgets(
    'a downloaded track plays from the album view even when the server '
    'calls it unavailable (v0.2.3)',
    (tester) async {
      final music = FakeMusicLibraryRepository()
        ..albumList = [testAlbum('al1', name: 'Kind of Blue')]
        ..trackList = [
          testTrack(
            't1',
            name: 'So What',
            trackNumber: 1,
            availability: MediaAvailability.remoteUnavailable,
          ),
        ];

      final store = InMemoryDownloadStore();
      final engine = FakeDownloadEngine()
        ..stored[mediaId('t1')] = Uri.file('/downloads/t1');
      store.records[mediaId('t1')] = downloadRecord(
        mediaId('t1'),
        title: 'So What',
        state: DownloadState.completed,
        owners: {DownloadOwner.album(mediaId('al1'))},
        totalBytes: 1000,
      );
      final downloads = fakeDownloadsCubit(store: store, engine: engine);
      addTearDown(downloads.close);
      await downloads.restore();

      final playback = fakePlaybackCubit();
      addTearDown(playback.close);

      await pumpThemed(
        tester,
        AlbumDetailPage(
          albumId: mediaId('al1'),
          detail: AlbumDetailCubit(music, FakeOfflineMode()),
          tracks: SongsCubit(
            music,
            FakeDownloadsLibrarySource(),
            FakeOfflineMode(),
          ),
        ),
        downloads: downloads,
        playback: playback,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();

      expect(playback.state.currentEntry?.title, 'So What');

      await playback.togglePlayPause();
      await tester.pumpAndSettle();
    },
  );
}
