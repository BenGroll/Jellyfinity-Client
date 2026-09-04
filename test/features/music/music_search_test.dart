import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/design/design.dart';
import 'package:jellyfinity/features/music/presentation/search/InlineMusicSearch.dart';
import 'package:jellyfinity/features/music/presentation/search/music_search_cubit.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';
import 'package:jellyfinity/features/music/presentation/widgets/music_rows.dart';

import '../../support/music_fakes.dart';
import '../../support/pump_app.dart';

/// A cubit this test owns and must close itself.
MusicSearchCubit _cubit(
  FakeMusicLibraryRepository music, [
  FakePlaylistRepository? playlists,
]) {
  final cubit = MusicSearchCubit(music, playlists ?? FakePlaylistRepository());
  addTearDown(cubit.close);
  return cubit;
}

/// A cubit handed to a widget, which closes it when the tree is disposed.
///
/// Deliberately *not* registered for teardown: closing it a second time
/// while a `BlocBuilder` is still attached wedges the test's shutdown.
MusicSearchCubit _pageCubit(
  FakeMusicLibraryRepository music, [
  FakePlaylistRepository? playlists,
]) => MusicSearchCubit(music, playlists ?? FakePlaylistRepository());

FakeMusicLibraryRepository _library() => FakeMusicLibraryRepository()
  ..artistList = [testArtist('a1', name: 'Miles Davis')]
  ..albumList = [testAlbum('al1', name: 'Miles Ahead')]
  ..trackList = [testTrack('t1', name: 'Miles Runs the Voodoo Down')];

void main() {
  group('cubit', () {
    test('waits for typing to stop before searching', () async {
      final music = _library();
      final cubit = _cubit(music);

      cubit.queryChanged('m');
      cubit.queryChanged('mi');
      cubit.queryChanged('miles');
      await Future<void>.delayed(MusicSearchCubit.debounce * 2);

      // One search for "miles", not one per keystroke.
      expect(music.calls.map((c) => c.searchTerm).toSet(), {'miles'});
      expect(music.calls, hasLength(3)); // artists, albums, songs
    });

    test('keeps the categories apart', () async {
      final cubit = _cubit(_library());

      cubit.queryChanged('miles');
      await cubit.submit();

      expect(cubit.state.artists.items.single.name, 'Miles Davis');
      expect(cubit.state.albums.items.single.name, 'Miles Ahead');
      expect(cubit.state.songs.items.single.name, 'Miles Runs the Voodoo Down');
      expect(cubit.state.status, MusicSearchStatus.results);
    });

    test('asks for a preview of each category, not every match', () async {
      final music = FakeMusicLibraryRepository()
        ..trackList = [
          for (var i = 0; i < 400; i++) testTrack('t$i', name: 'Blue $i'),
        ];
      final cubit = _cubit(music);

      cubit.queryChanged('blue');
      await cubit.submit();

      expect(cubit.state.songs.items, hasLength(MusicSearchCubit.previewLimit));
      // But it knows how many there are, so it can offer the rest.
      expect(cubit.state.songs.total, 400);
      expect(cubit.state.songs.hasMore, isTrue);
    });

    test('clearing the field puts the screen back to idle', () async {
      final cubit = _cubit(_library());
      cubit.queryChanged('miles');
      await cubit.submit();

      cubit.queryChanged('');

      expect(cubit.state.status, MusicSearchStatus.idle);
      expect(cubit.state.artists.items, isEmpty);
    });

    test('one dead category does not fail the search', () async {
      final playlists = FakePlaylistRepository()
        ..failure = const RecoverableFailure('Playlists are unavailable.');
      final cubit = _cubit(_library(), playlists);

      cubit.queryChanged('miles');
      await cubit.submit();

      expect(cubit.state.playlists.failure, isA<RecoverableFailure>());
      expect(cubit.state.artists.items, isNotEmpty);
      expect(cubit.state.wholeSearchFailure, isNull);
    });

    test('every category failing is one failure, said once', () async {
      final music = _library()
        ..failure = const RecoverableFailure('Could not reach the server.');
      final playlists = FakePlaylistRepository()
        ..failure = const RecoverableFailure('Could not reach the server.');
      final cubit = _cubit(music, playlists);

      cubit.queryChanged('miles');
      await cubit.submit();

      expect(cubit.state.wholeSearchFailure, isA<RecoverableFailure>());
    });

    test('a slow answer to an old query never wins', () async {
      final music = _library()
        ..responseDelay = const Duration(milliseconds: 40);
      final cubit = _cubit(music);

      cubit.queryChanged('mil');
      unawaitedSubmit(cubit);
      cubit.queryChanged('coltrane');
      await cubit.submit();

      expect(cubit.state.query, 'coltrane');
      expect(cubit.state.status, MusicSearchStatus.results);
    });
  });

  group('screen', () {
    setUp(() {
      MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
    });
    tearDown(() => MediaArtwork.imageBuilderOverride = null);

    // The search field autofocuses, so its caret blinks forever and
    // pumpAndSettle would never return. Frames are pumped explicitly
    // instead.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('invites a search before anything is typed', (tester) async {
      await pumpThemed(
        tester,
        InlineMusicSearch(cubit: _pageCubit(_library())),
      );
      await settle(tester);

      expect(find.text('Search your music'), findsOneWidget);
      expect(find.byType(EmptyStateView), findsOneWidget);
    });

    testWidgets('groups results under their category headings', (tester) async {
      await pumpThemed(
        tester,
        InlineMusicSearch(cubit: _pageCubit(_library())),
      );
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'miles');
      await tester.pump(MusicSearchCubit.debounce);
      await settle(tester);

      expect(find.text('Artists'), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Songs'), findsOneWidget);
      expect(find.widgetWithText(ArtistRow, 'Miles Davis'), findsOneWidget);
      // Playlists matched nothing, so its heading is not shown at all.
      expect(find.text('Playlists'), findsNothing);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await pumpThemed(
        tester,
        InlineMusicSearch(cubit: _pageCubit(_library())),
      );
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump(MusicSearchCubit.debounce);
      await settle(tester);

      expect(find.text('No matches'), findsOneWidget);
    });
  });
}

/// Starts a search without waiting for it, to model a slow answer that is
/// still in flight when the query changes.
void unawaitedSubmit(MusicSearchCubit cubit) {
  cubit.submit();
}
