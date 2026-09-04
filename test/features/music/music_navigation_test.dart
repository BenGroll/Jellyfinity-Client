import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/app/router/AppRouter.dart';
import 'package:jellyfinity/features/music/presentation/detail/AlbumDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/detail/ArtistDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/library/LibraryPage.dart';
import 'package:jellyfinity/features/music/presentation/search/InlineMusicSearch.dart';
import 'package:jellyfinity/features/music/presentation/search/music_search_cubit.dart';
import 'package:jellyfinity/features/music/presentation/search/SearchCategoryPage.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';
import 'package:jellyfinity/features/music/presentation/widgets/music_rows.dart';

import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/pump_app.dart';
import '../../support/session_fakes.dart';

/// Signs in and opens the Library section through the real router, so the
/// routes under test are the ones the app ships.
Future<AppRouter> _openLibrary(
  WidgetTester tester,
  FakeMusicLibraryRepository music, {
  FakeMediaMetadataRepository? metadata,
  PlaybackCubit? playback,
}) async {
  registerMusicCubits(music: music, metadata: metadata);
  final scope = TestSessionScope();
  final router = AppRouter(scope.cubit);
  final s = await pumpApp(
    tester,
    scope: scope,
    router: router,
    playback: playback,
  );
  await s.signIn();
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Library'),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(() {
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  testWidgets('the Library tab opens the music library', (tester) async {
    await _openLibrary(tester, FakeMusicLibraryRepository());

    expect(find.byType(LibraryPage), findsOneWidget);
  });

  testWidgets('artist to album, and back again', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..artistList = [testArtist('a1', name: 'Miles Davis')]
      ..albumList = [testAlbum('al1', name: 'Kind of Blue')]
      ..trackList = [testTrack('t1', name: 'So What', albumId: 'al1')];

    await _openLibrary(tester, music);

    await tester.tap(find.text('Miles Davis'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtistDetailPage), findsOneWidget);

    await tester.tap(find.text('Kind of Blue'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumDetailPage), findsOneWidget);
    expect(find.text('So What'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ArtistDetailPage), findsOneWidget);
  });

  testWidgets('tapping a track starts playing it', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..artistList = [testArtist('a1', name: 'Miles Davis')]
      ..albumList = [testAlbum('al1', name: 'Kind of Blue')]
      ..trackList = [testTrack('t1', name: 'So What', albumId: 'al1')];

    final playback = fakePlaybackCubit();
    await _openLibrary(tester, music, playback: playback);
    await tester.tap(find.text('Miles Davis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kind of Blue'));
    await tester.pumpAndSettle();

    expect(
      find.text('So What'),
      findsOneWidget,
      reason: 'only in the track list — the mini-player is not up yet',
    );

    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();

    expect(
      find.text('So What'),
      findsNWidgets(2),
      reason: 'the track list row, plus the mini-player showing it',
    );
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    // Playing starts a position-save timer; pause before the test ends
    // so no timer outlives the widget tree.
    await playback.togglePlayPause();
  });

  testWidgets('Add to Queue from a track row', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..artistList = [testArtist('a1', name: 'Miles Davis')]
      ..albumList = [testAlbum('al1', name: 'Kind of Blue')]
      ..trackList = [
        testTrack('t1', name: 'So What', albumId: 'al1'),
        testTrack('t2', name: 'Freddie Freeloader', albumId: 'al1'),
      ];

    final playback = fakePlaybackCubit();
    await _openLibrary(tester, music, playback: playback);
    await tester.tap(find.text('Miles Davis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kind of Blue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();
    // Tapping a track queues the whole loaded album from that point, so
    // both tracks are already in the queue.
    expect(playback.state.queue.entries, hasLength(2));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Play Next'), findsOneWidget);
    await tester.tap(find.text('Add to Queue'));
    await tester.pumpAndSettle();

    expect(
      playback.state.queue.entries,
      hasLength(3),
      reason: 'Add to Queue appends even a track already in the queue',
    );

    await playback.togglePlayPause();
  });

  testWidgets('a music detail keeps the bottom navigation', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..artistList = [testArtist('a1', name: 'Miles Davis')];

    await _openLibrary(tester, music);
    await tester.tap(find.text('Miles Davis'));
    await tester.pumpAndSettle();

    // The section owns the stack, so the shell stays around it.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('an id that is not a MediaId key goes nowhere', (tester) async {
    // A stale link or a hand-typed URL degrades to not-found instead of
    // throwing on a half-parsed id.
    final router = await _openLibrary(tester, FakeMusicLibraryRepository());

    router.config.go('/library/album/not-a-key');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets('Home leads into the music library', (tester) async {
    registerMusicCubits(music: FakeMusicLibraryRepository());
    final scope = TestSessionScope();
    final s = await pumpApp(tester, scope: scope);
    await s.signIn();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Browse music'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryPage), findsOneWidget);
  });

  testWidgets('"show all" opens the full results for one category', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..artistList = [
        for (var i = 0; i < 12; i++) testArtist('a$i', name: 'Miles $i'),
      ];
    await _openLibrary(tester, music);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Miles');
    await tester.pump(MusicSearchCubit.debounce);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Five of twelve are previewed; the rest are one tap away.
    await tester.tap(find.text('Show all 12'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byType(SearchCategoryPage), findsOneWidget);
    // The full list, not the five-row preview.
    expect(find.byType(ArtistRow), findsWidgets);
    expect(find.text('Miles 0'), findsOneWidget);
  });

  testWidgets('search is reachable at the top of the UI, inline', (
    tester,
  ) async {
    await _openLibrary(tester, FakeMusicLibraryRepository());

    // Before: just the header's search affordance, no results view.
    expect(find.byType(InlineMusicSearch), findsNothing);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    // Inline, not a pushed page: the bottom navigation is still visible.
    expect(find.byType(InlineMusicSearch), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Closing it returns to the library, still on the same tab.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(InlineMusicSearch), findsNothing);
    expect(find.byType(LibraryPage), findsOneWidget);
  });
}
