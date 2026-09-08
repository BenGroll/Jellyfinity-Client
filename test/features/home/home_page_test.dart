import 'package:flutter/material.dart' show Icons, InkWell, NavigationBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/connectivity/OfflineLibraryScope.dart';
import 'package:jellyfinity/domain/media/ListeningContext.dart';
import 'package:jellyfinity/domain/media/ListeningHistoryEntry.dart';
import 'package:jellyfinity/domain/media/page.dart';
import 'package:jellyfinity/domain/playback/PlaybackQueue.dart';
import 'package:jellyfinity/domain/playback/QueueEntry.dart';
import 'package:jellyfinity/features/favorites/presentation/FavoritesPage.dart';
import 'package:jellyfinity/features/music/presentation/detail/AlbumDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/library/LibraryPage.dart';
import 'package:jellyfinity/features/playback/presentation/NowPlayingPage.dart';

import '../../support/music_fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/pump_app.dart';
import '../../support/session_fakes.dart';
import '../../support/settings_fakes.dart';

ListeningHistoryEntry _albumEntry(String id, {DateTime? lastPlayedAt}) {
  final at = lastPlayedAt ?? DateTime.utc(2026, 9, 7, 12);
  return ListeningHistoryEntry(
    context: ListeningContext(
      kind: ListeningContextKind.album,
      id: mediaId(id),
      name: 'Album $id',
    ),
    firstPlayedAt: at,
    lastPlayedAt: at,
    playCount: 3,
  );
}

/// A [PlaybackCubit] with a saved queue already restored (paused) — the
/// launch state "Continue listening" is built for.
Future<PlaybackCubit> _restoredPlayback(QueueEntry entry) async {
  final cubit = PlaybackCubit(
    FakePlaybackEngine(),
    FakeQueueRepository()
      ..queue = PlaybackQueue.empty.withEntries([entry], startIndex: 0),
    FakeAudioSourceResolver(),
    RecordingPlaybackProgressRepository(),
    RecordingListeningHistoryRepository(),
    fakeSettingsCubit(),
  );
  await cubit.restore();
  return cubit;
}

QueueEntry _entry(String id) => QueueEntry(
  id: mediaId(id),
  title: 'Blue in Green',
  artist: 'Miles Davis',
  albumId: mediaId('al-$id'),
  albumName: 'Kind of Blue',
  duration: const Duration(minutes: 5, seconds: 37),
);

Future<TestSessionScope> _pumpHome(
  WidgetTester tester, {
  SeededListeningHistoryRepository? history,
  FakeMusicLibraryRepository? music,
  PlaybackCubit? playback,
  OfflineLibraryScope scope = OfflineLibraryScope.unlimited,
  bool offline = false,
}) async {
  registerRecentlyPlayedCubit(
    history: history ?? SeededListeningHistoryRepository(),
  );
  registerMusicCubits(music: music ?? FakeMusicLibraryRepository());
  final s = await pumpApp(
    tester,
    playback: playback,
    settings: fakeSettingsCubit(offlineLibraryScope: scope),
    offline: fakeOfflineCubit(manual: offline),
  );
  await s.signIn();
  await tester.pumpAndSettle();
  return s;
}

void main() {
  testWidgets('an untouched Home offers the library', (tester) async {
    await _pumpHome(tester);

    expect(find.text('Nothing to pick up yet'), findsOneWidget);

    await tester.tap(find.text('Browse music'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryPage), findsOneWidget);
  });

  testWidgets('Recently played lists what the profile returned to', (
    tester,
  ) async {
    final history = SeededListeningHistoryRepository()
      ..entries = [
        _albumEntry('newer', lastPlayedAt: DateTime.utc(2026, 9, 7)),
        _albumEntry('older', lastPlayedAt: DateTime.utc(2026, 9, 1)),
      ];
    await _pumpHome(tester, history: history);

    expect(find.text('Recently played'), findsOneWidget);
    expect(find.text('Album newer'), findsOneWidget);
    expect(find.text('Album older'), findsOneWidget);

    final newerX = tester.getTopLeft(find.text('Album newer')).dx;
    final olderX = tester.getTopLeft(find.text('Album older')).dx;
    expect(newerX, lessThan(olderX));
  });

  testWidgets('a recently played album opens it', (tester) async {
    final history = SeededListeningHistoryRepository()
      ..entries = [_albumEntry('kob')];
    final music = FakeMusicLibraryRepository()
      ..albumList = [testAlbum('kob', name: 'Album kob')];
    await _pumpHome(tester, history: history, music: music);

    await tester.tap(find.text('Album kob'));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumDetailPage), findsOneWidget);
    // Pushed onto Home's own stack, not a switch to the Library tab.
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('Continue listening resumes the saved queue', (tester) async {
    final playback = await _restoredPlayback(_entry('t1'));
    addTearDown(playback.close);
    await _pumpHome(tester, playback: playback);

    expect(find.text('Continue listening'), findsOneWidget);
    // The card, and again in the mini-player underneath it.
    expect(find.text('Blue in Green'), findsWidgets);

    await tester.tap(find.byIcon(Icons.play_circle_fill_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(NowPlayingPage), findsOneWidget);
    expect(playback.state.isPlaying, isTrue);

    // Settle playback so its position-save timer does not outlive the test.
    await playback.togglePlayPause();
  });

  testWidgets('a failing Recently played leaves the rest of Home usable', (
    tester,
  ) async {
    final history = SeededListeningHistoryRepository()
      ..failure = const UnexpectedFailure('history is unreadable');
    final playback = await _restoredPlayback(_entry('t2'));
    addTearDown(playback.close);
    await _pumpHome(tester, history: history, playback: playback);

    // The dead section shows its own retry, not a blank screen...
    expect(find.text('Try again'), findsOneWidget);
    // ...and Continue listening still works.
    expect(find.text('Continue listening'), findsOneWidget);
  });

  testWidgets('offline downloads-only hides what cannot play', (tester) async {
    final history = SeededListeningHistoryRepository()
      ..entries = [_albumEntry('streamed')];
    await _pumpHome(
      tester,
      history: history,
      offline: true,
      scope: OfflineLibraryScope.limited,
    );

    // Nothing is downloaded, so the streamed-only album is not offered...
    expect(find.text('Album streamed'), findsNothing);
    // ...and with no queue either, Home falls back to its empty state.
    expect(find.text('Nothing to pick up yet'), findsOneWidget);
  });

  testWidgets('offline (full library) marks what cannot play in place', (
    tester,
  ) async {
    final history = SeededListeningHistoryRepository()
      ..entries = [_albumEntry('streamed')];
    await _pumpHome(tester, history: history, offline: true);

    expect(find.text('Album streamed'), findsOneWidget);
    expect(find.text('Not playable offline'), findsOneWidget);
  });

  testWidgets('Recently added shows the newest albums (v0.3.3)', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..recentlyAddedList = [testAlbum('n', name: 'Just Landed')];
    await _pumpHome(tester, music: music);

    expect(find.text('Recently added'), findsOneWidget);
    expect(find.text('Just Landed'), findsOneWidget);
  });

  testWidgets('Recently added is absent when the library has none', (
    tester,
  ) async {
    await _pumpHome(tester);

    expect(find.text('Recently added'), findsNothing);
  });

  testWidgets('a recently added album opens it', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..recentlyAddedList = [testAlbum('kob', name: 'Kind of Blue')]
      ..albumList = [testAlbum('kob', name: 'Kind of Blue')];
    await _pumpHome(tester, music: music);

    await tester.tap(find.text('Kind of Blue'));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumDetailPage), findsOneWidget);
  });

  testWidgets('offline, Recently added shows the saved list and says so', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..recentlyAddedList = [testAlbum('n', name: 'Saved Album')]
      ..source = PageSource.cache;
    await _pumpHome(tester, music: music, offline: true);

    expect(find.text('Saved Album'), findsOneWidget);
    // The strip is honest that it could not check for new music offline.
    expect(find.textContaining('Saved list'), findsOneWidget);
  });

  testWidgets('the downloads-only scope drops Recently added', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..recentlyAddedList = [testAlbum('n', name: 'New Album')]
      ..source = PageSource.cache;
    await _pumpHome(
      tester,
      music: music,
      offline: true,
      scope: OfflineLibraryScope.limited,
    );

    expect(find.text('Recently added'), findsNothing);
    expect(find.text('New Album'), findsNothing);
  });

  testWidgets('Favorites shows starred albums and artists (v0.3.4)', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..favoriteAlbumList = [testAlbum('a', name: 'Starred Album')]
      ..favoriteArtistList = [testArtist('b', name: 'Starred Artist')];
    await _pumpHome(tester, music: music);

    // The section heading, plus the bottom-nav destination label.
    expect(find.text('Favorites'), findsNWidgets(2));
    expect(find.text('Starred Album'), findsOneWidget);
    expect(find.text('Starred Artist'), findsOneWidget);
  });

  testWidgets('Favorites section is absent when nothing is starred', (
    tester,
  ) async {
    await _pumpHome(tester);

    // Only the bottom-nav destination, never the Home section.
    expect(find.text('Favorites'), findsOneWidget);
  });

  testWidgets('the Favorites header opens the Favorites destination', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..favoriteAlbumList = [testAlbum('a', name: 'Starred Album')];
    await _pumpHome(tester, music: music);

    await tester.tap(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right_rounded),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FavoritesPage), findsOneWidget);
  });

  testWidgets('a favorited album on Home opens it', (tester) async {
    final music = FakeMusicLibraryRepository()
      ..favoriteAlbumList = [testAlbum('kob', name: 'Kind of Blue')]
      ..albumList = [testAlbum('kob', name: 'Kind of Blue')];
    await _pumpHome(tester, music: music);

    await tester.tap(find.text('Kind of Blue'));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumDetailPage), findsOneWidget);
  });
}
