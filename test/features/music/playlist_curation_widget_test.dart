import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/router/AppRouter.dart';
import 'package:jellyfinity/app/router/route_paths.dart';
import 'package:jellyfinity/design/design.dart';
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart';
import 'package:jellyfinity/features/music/presentation/library/LibraryPage.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';

import '../../support/music_fakes.dart';
import '../../support/pump_app.dart';
import '../../support/session_fakes.dart';

Future<void> _pumpLibrary(
  WidgetTester tester, {
  required FakeMusicLibraryRepository music,
  required FakePlaylistRepository playlists,
  required FakePlaylistEditor editor,
}) async {
  registerMusicCubits(music: music, playlists: playlists, editor: editor);
  await pumpThemed(
    tester,
    LibraryPage(
      artists: ArtistsCubit(music),
      albums: AlbumsCubit(music),
      songs: SongsCubit(music),
      playlists: PlaylistsCubit(playlists),
    ),
  );
}

void main() {
  setUp(() {
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  testWidgets('creates a playlist from the Playlists tab', (tester) async {
    final editor = FakePlaylistEditor();
    await _pumpLibrary(
      tester,
      music: FakeMusicLibraryRepository(),
      playlists: FakePlaylistRepository(),
      editor: editor,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Playlists'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Road Trip');
    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await tester.pumpAndSettle();

    expect(editor.calls, contains('create(Road Trip)'));
  });

  testWidgets('renames a playlist from its overflow menu', (tester) async {
    final editor = FakePlaylistEditor();
    final playlists = FakePlaylistRepository()
      ..playlistList = [testPlaylist('pl1', name: 'Old Name')];
    await _pumpLibrary(
      tester,
      music: FakeMusicLibraryRepository(),
      playlists: playlists,
      editor: editor,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Playlists'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New Name');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(editor.calls, contains('rename(${testPlaylist('pl1').id}, New Name)'));
  });

  testWidgets('deletes a playlist from its overflow menu, after confirming', (
    tester,
  ) async {
    final editor = FakePlaylistEditor();
    final playlists = FakePlaylistRepository()
      ..playlistList = [testPlaylist('pl1', name: 'Old Name')];
    await _pumpLibrary(
      tester,
      music: FakeMusicLibraryRepository(),
      playlists: playlists,
      editor: editor,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Playlists'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(editor.calls.any((c) => c.startsWith('delete(')), isTrue);
  });

  testWidgets('adds a track to a playlist from its overflow menu', (
    tester,
  ) async {
    final editor = FakePlaylistEditor();
    final playlists = FakePlaylistRepository()
      ..playlistList = [testPlaylist('pl1', name: 'Favorites')];
    final music = FakeMusicLibraryRepository()
      ..trackList = [testTrack('t1', name: 'So What')];
    await _pumpLibrary(tester, music: music, playlists: playlists, editor: editor);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Songs'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    expect(editor.calls.any((c) => c.startsWith('addTracks(')), isTrue);
    expect(editor.calls.single, contains('t1'));
  });

  testWidgets('merges two playlists into a new one', (tester) async {
    // Needs a real GoRouter: on success the page navigates to the new
    // playlist's detail route, which `pumpThemed` (a bare `MaterialApp`)
    // cannot resolve.
    final editor = FakePlaylistEditor();
    final playlists = FakePlaylistRepository()
      ..playlistList = [
        testPlaylist('pl1', name: 'Morning'),
        testPlaylist('pl2', name: 'Evening'),
      ]
      ..trackList = [testTrack('t1')];
    registerMusicCubits(
      music: FakeMusicLibraryRepository(),
      playlists: playlists,
      editor: editor,
    );
    final scope = TestSessionScope();
    final router = AppRouter(scope.cubit);
    final s = await pumpApp(tester, scope: scope, router: router);
    await s.signIn();
    await tester.pumpAndSettle();

    router.config.pushNamed(RouteNames.libraryMergePlaylists);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Morning'));
    await tester.tap(find.text('Evening'));
    await tester.enterText(
      find.widgetWithText(TextField, 'New playlist name'),
      'Combined',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Merge'));
    await tester.pumpAndSettle();

    expect(editor.calls.first, contains('create(Combined)'));
    expect(editor.calls.where((c) => c.startsWith('addTracks')), hasLength(2));
  });
}
