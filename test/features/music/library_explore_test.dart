import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/router/AppRouter.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/features/music/presentation/detail/AlbumDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/detail/ArtistDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/library/LibraryFacetPage.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';

import '../../support/music_fakes.dart';
import '../../support/pump_app.dart';
import '../../support/session_fakes.dart';

/// Signs in, opens Library through the real router, and switches to the
/// Explore tab (v0.4.4) — the same shape `music_navigation_test.dart`'s
/// `_openLibrary` uses, plus the one extra tab tap every test here needs.
Future<AppRouter> _openExplore(
  WidgetTester tester,
  FakeMusicLibraryRepository music,
) async {
  registerMusicCubits(music: music);
  final scope = TestSessionScope();
  final router = AppRouter(scope.cubit);
  final s = await pumpApp(tester, scope: scope, router: router);
  await s.signIn();
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Library'),
    ),
  );
  await tester.pumpAndSettle();
  // The TabBar is scrollable and "Explore" is its last tab, so it may
  // start off-screen.
  await tester.ensureVisible(find.text('Explore'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Explore'));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(() {
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  testWidgets('genre and decade shelves show the library\'s facets', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..genreList = ['Jazz', 'Rock']
      ..decadeList = [2020, 1950];

    await _openExplore(tester, music);

    expect(find.text('Jazz'), findsOneWidget);
    expect(find.text('Rock'), findsOneWidget);
    expect(find.text('2020s'), findsOneWidget);
    expect(find.text('1950s'), findsOneWidget);
  });

  testWidgets('an empty library says so, honestly, not as an error', (
    tester,
  ) async {
    await _openExplore(tester, FakeMusicLibraryRepository());

    expect(find.text('No genres tagged in your library yet.'), findsOneWidget);
    expect(
      find.text('No album release years in your library yet.'),
      findsOneWidget,
    );
  });

  testWidgets('a server without the facet endpoints says so', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..facetFailure = const RecoverableFailure('You are offline.');

    await _openExplore(tester, music);

    expect(
      find.textContaining('Needs a connection'),
      findsNWidgets(2), // one line for genres, one for decades
    );
  });

  testWidgets('tapping a genre opens every album in it', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..genreList = ['Jazz']
      ..albumList = [testAlbum('al1', name: 'Kind of Blue')];

    await _openExplore(tester, music);
    await tester.tap(find.text('Jazz'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryFacetPage), findsOneWidget);
    // A genre page opens on Artists (matching Library's own tab order);
    // Albums is the second tab.
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    expect(find.text('Kind of Blue'), findsOneWidget);
  });

  testWidgets('tapping a decade opens every album from it', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..decadeList = [1990]
      ..albumList = [testAlbum('al1', name: 'Blue Train')];

    await _openExplore(tester, music);
    await tester.tap(find.text('1990s'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryFacetPage), findsOneWidget);
    expect(find.text('Blue Train'), findsOneWidget);
  });

  testWidgets('a genre page opens on Artists, and has no Decade-only tabs', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..genreList = ['Jazz']
      ..artistList = [testArtist('a1', name: 'Miles Davis')];

    await _openExplore(tester, music);
    await tester.tap(find.text('Jazz'));
    await tester.pumpAndSettle();

    expect(find.text('Miles Davis'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Songs'), findsOneWidget);
  });

  testWidgets('a decade page has no Artists tab', (tester) async {
    final music = FakeMusicLibraryRepository()..decadeList = [1990];

    await _openExplore(tester, music);
    await tester.tap(find.text('1990s'));
    await tester.pumpAndSettle();

    expect(find.text('Artists'), findsNothing);
    expect(find.text('Albums'), findsOneWidget);
  });

  testWidgets('a random album pick opens that album', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..randomAlbumPick = testAlbum('al1', name: 'Kind of Blue')
      ..albumList = [testAlbum('al1', name: 'Kind of Blue')];

    await _openExplore(tester, music);
    await tester.tap(find.text('Album'));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumDetailPage), findsOneWidget);
  });

  testWidgets('a random artist pick opens that artist', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..randomArtistPick = testArtist('a1', name: 'Miles Davis')
      ..artistList = [testArtist('a1', name: 'Miles Davis')];

    await _openExplore(tester, music);
    await tester.tap(find.text('Artist'));
    await tester.pumpAndSettle();

    expect(find.byType(ArtistDetailPage), findsOneWidget);
  });

  testWidgets('an empty scope reports the random pick could not be made', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository();

    await _openExplore(tester, music);
    await tester.tap(find.text('Album'));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumDetailPage), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
