import 'package:flutter/material.dart' show Icons, NavigationBar, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/app/router/AppRouter.dart';
import 'package:jellyfinity/features/favorites/presentation/FavoritesPage.dart';
import 'package:jellyfinity/features/music/presentation/detail/AlbumDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';

import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/pump_app.dart';
import '../../support/session_fakes.dart';

Future<void> _openFavorites(
  WidgetTester tester,
  FakeMusicLibraryRepository music, {
  FakeFavoritesRepository? favorites,
  PlaybackCubit? playback,
}) async {
  registerMusicCubits(music: music, favorites: favorites);
  final scope = TestSessionScope();
  final s = await pumpApp(
    tester,
    scope: scope,
    router: AppRouter(scope.cubit),
    playback: playback,
  );
  await s.signIn();
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Favorites'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  testWidgets('lists starred artists, albums and songs across three tabs', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..favoriteArtistList = [testArtist('a', name: 'Starred Artist')]
      ..favoriteAlbumList = [testAlbum('b', name: 'Starred Album')]
      ..favoriteTrackList = [testTrack('c', name: 'Starred Song')];
    await _openFavorites(tester, music);

    expect(find.byType(FavoritesPage), findsOneWidget);
    expect(find.text('Starred Artist'), findsOneWidget);

    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    expect(find.text('Starred Album'), findsOneWidget);

    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();
    expect(find.text('Starred Song'), findsOneWidget);
  });

  testWidgets('an empty tab says so rather than showing an error', (
    tester,
  ) async {
    await _openFavorites(tester, FakeMusicLibraryRepository());

    expect(find.text('No favorite artists yet'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('the favorite songs play straight through, like a playlist', (
    tester,
  ) async {
    final playback = fakePlaybackCubit();
    final music = FakeMusicLibraryRepository()
      ..favoriteTrackList = [
        testTrack('t1', name: 'First'),
        testTrack('t2', name: 'Second'),
      ];
    await _openFavorites(tester, music, playback: playback);

    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_circle_filled_rounded));
    await tester.pumpAndSettle();

    expect(playback.state.queue.entries, hasLength(2));

    await playback.togglePlayPause();
  });

  testWidgets('unfavoriting on the album page updates the destination', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..favoriteAlbumList = [testAlbum('kob', name: 'Kind of Blue')]
      ..albumList = [testAlbum('kob', name: 'Kind of Blue', isFavorite: true)];
    music.tracksByAlbum['kob'] = [testTrack('t1', name: 'So What')];
    final favorites = FakeFavoritesRepository(library: music);
    await _openFavorites(tester, music, favorites: favorites);

    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    expect(find.text('Kind of Blue'), findsOneWidget);

    await tester.tap(find.text('Kind of Blue'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumDetailPage), findsOneWidget);

    // The heart is filled (the album is a favorite); tap it to remove.
    await tester.tap(find.byTooltip('Remove from favorites'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(FavoritesPage), findsOneWidget);
    expect(find.text('Kind of Blue'), findsNothing);
    expect(find.text('No favorite albums yet'), findsOneWidget);
  });
}
