import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/design/design.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart';
import 'package:jellyfinity/features/music/presentation/library/LibraryPage.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';
import 'package:jellyfinity/features/music/presentation/widgets/music_rows.dart';
import 'package:jellyfinity/features/music/presentation/widgets/music_skeletons.dart';
import 'package:jellyfinity/features/music/presentation/widgets/paged_collection_view.dart';

import '../../support/music_fakes.dart';
import '../../support/pump_app.dart';

/// Pumps the Music section with cubits over [music].
Future<void> _pumpMusic(
  WidgetTester tester,
  FakeMusicLibraryRepository music, {
  FakePlaylistRepository? playlists,
  int pageSize = PageRequest.defaultLimit,
}) async {
  final playlistRepository = playlists ?? FakePlaylistRepository();
  await pumpThemed(
    tester,
    LibraryPage(
      artists: ArtistsCubit(music, pageSize: pageSize),
      albums: AlbumsCubit(music, pageSize: pageSize),
      songs: SongsCubit(music, pageSize: pageSize),
      playlists: PlaylistsCubit(playlistRepository, pageSize: pageSize),
    ),
  );
}

void main() {
  setUp(() {
    // Never let a widget test reach the artwork cache or the network.
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  testWidgets('shows the shape of the list before the artists arrive', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..artistList = [testArtist('a1', name: 'Miles Davis')]
      ..responseDelay = const Duration(milliseconds: 50);

    await _pumpMusic(tester, music);
    await tester.pump();

    // A skeleton in the shape of the content, never a bare spinner.
    expect(find.byType(MusicListSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(MusicListSkeleton), findsNothing);
    expect(find.text('Miles Davis'), findsOneWidget);
  });

  testWidgets('offers the four ways into a music library', (tester) async {
    await _pumpMusic(tester, FakeMusicLibraryRepository());
    await tester.pumpAndSettle();

    for (final tab in ['Artists', 'Albums', 'Songs', 'Playlists']) {
      expect(find.widgetWithText(Tab, tab), findsOneWidget);
    }
  });

  testWidgets('an empty library is empty, not broken', (tester) async {
    await _pumpMusic(tester, FakeMusicLibraryRepository());
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('No artists yet'), findsOneWidget);
    expect(find.byType(ErrorStateView), findsNothing);
  });

  testWidgets('an unreachable server offers a retry that works', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..artistList = [testArtist('a1', name: 'Miles Davis')]
      ..failure = const RecoverableFailure('Could not reach the server.');

    await _pumpMusic(tester, music);
    await tester.pumpAndSettle();
    expect(find.byType(ErrorStateView), findsOneWidget);

    music.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorStateView), findsNothing);
    expect(find.text('Miles Davis'), findsOneWidget);
  });

  testWidgets('says out loud when it is showing the saved copy', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..artistList = [testArtist('a1', name: 'Miles Davis')]
      ..source = PageSource.cache;

    await _pumpMusic(tester, music);
    await tester.pumpAndSettle();

    expect(find.byType(SavedCopyNotice), findsOneWidget);
    expect(find.text('Miles Davis'), findsOneWidget);
  });

  testWidgets('keeps the songs it could read and marks the one it could not', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..trackList = [
        testTrack('t1', name: 'So What'),
        testTrack('t2', name: 'Blue in Green'),
      ]
      ..unavailable = const [
        UnavailableItem(id: 't3', reason: 'This song is unavailable.'),
      ];

    await _pumpMusic(tester, music);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Songs'));
    await tester.pumpAndSettle();

    expect(find.text('So What'), findsOneWidget);
    expect(find.text('Blue in Green'), findsOneWidget);
    // The unusable row is visible and labelled, not silently dropped.
    expect(find.byType(UnavailableRow), findsOneWidget);
    expect(find.byType(UnavailableBadge), findsOneWidget);
  });

  testWidgets('loads the next window as the list is scrolled', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..trackList = [
        for (var i = 0; i < 300; i++) testTrack('t$i', name: 'Song $i'),
      ];

    await _pumpMusic(tester, music, pageSize: 20);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Songs'));
    await tester.pumpAndSettle();

    final firstWindow = music.calls.length;
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -1200),
      1200,
    );
    await tester.pumpAndSettle();

    expect(music.calls.length, greaterThan(firstWindow));
    // Still a window at a time — never the whole collection.
    expect(music.calls.every((c) => c.page.limit == 20), isTrue);
  });
}
