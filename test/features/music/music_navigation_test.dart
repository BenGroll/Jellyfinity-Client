import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/features/music/presentation/detail/AlbumDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/detail/ArtistDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/library/MusicPage.dart';
import 'package:jellyfinity/features/music/presentation/search/MusicSearchPage.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';

import 'package:jellyfinity/app/JellyfinityApp.dart';
import 'package:jellyfinity/app/router/AppRouter.dart';

import '../../support/music_fakes.dart';
import '../../support/session_fakes.dart';

/// Signs in and opens the Music section through the real router, so the
/// routes under test are the ones the app ships.
Future<AppRouter> _openMusic(
  WidgetTester tester,
  FakeMusicLibraryRepository music, {
  FakeMediaMetadataRepository? metadata,
}) async {
  final scope = TestSessionScope();
  addTearDown(scope.cubit.close);
  registerAuthCubits(scope);
  registerMusicCubits(music: music, metadata: metadata);

  final router = AppRouter(scope.cubit);
  await tester.pumpWidget(
    JellyfinityApp(router: router.config, session: scope.cubit),
  );
  await scope.cubit.restore();
  await tester.pumpAndSettle();
  await scope.signIn();
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Music'),
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

  testWidgets('the Music tab opens the music library', (tester) async {
    await _openMusic(tester, FakeMusicLibraryRepository());

    expect(find.byType(MusicPage), findsOneWidget);
  });

  testWidgets('artist to album, and back again', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..artistList = [testArtist('a1', name: 'Miles Davis')]
      ..albumList = [testAlbum('al1', name: 'Kind of Blue')]
      ..trackList = [testTrack('t1', name: 'So What', albumId: 'al1')];

    await _openMusic(tester, music);

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

  testWidgets('a music detail keeps the bottom navigation', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..artistList = [testArtist('a1', name: 'Miles Davis')];

    await _openMusic(tester, music);
    await tester.tap(find.text('Miles Davis'));
    await tester.pumpAndSettle();

    // The section owns the stack, so the shell stays around it.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('an id that is not a MediaId key goes nowhere', (tester) async {
    // A stale link or a hand-typed URL degrades to not-found instead of
    // throwing on a half-parsed id.
    final router = await _openMusic(tester, FakeMusicLibraryRepository());

    router.config.go('/music/album/not-a-key');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets('search is reachable from the library', (tester) async {
    await _openMusic(tester, FakeMusicLibraryRepository());

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(MusicSearchPage), findsOneWidget);
  });
}
