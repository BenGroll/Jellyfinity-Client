import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/design/design.dart';
import 'package:jellyfinity/features/music/presentation/detail/AlbumDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/detail/media_detail_cubit.dart';
import 'package:jellyfinity/features/music/presentation/detail/PlaylistDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/detail/playlist_edit_cubit.dart';
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';
import 'package:jellyfinity/features/music/presentation/widgets/music_rows.dart';
import 'package:jellyfinity/features/music/presentation/widgets/music_skeletons.dart';

import '../../support/music_fakes.dart';
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
      detail: AlbumDetailCubit(music),
      tracks: SongsCubit(music),
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
        detail: PlaylistDetailCubit(metadata),
        tracks: PlaylistTracksCubit(playlists),
        edit: PlaylistEditCubit(playlists, FakePlaylistEditor()),
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
}
