import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/di/service_locator.dart';
import 'package:jellyfinity/features/music/presentation/widgets/ArtworkBackground.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/domain/playback/Lyrics.dart';
import 'package:jellyfinity/domain/playback/CrossfadeSettings.dart';
import 'package:jellyfinity/domain/playback/NormalizationSettings.dart';
import 'package:jellyfinity/domain/playback/PlaybackFailure.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';
import 'package:jellyfinity/domain/playback/stream_quality.dart';
import 'package:jellyfinity/domain/playback/TrackSourceInfo.dart';
import 'package:jellyfinity/features/music/presentation/detail/ArtistDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';
import 'package:jellyfinity/features/playback/presentation/LyricsPage.dart';
import 'package:jellyfinity/features/playback/presentation/MiniPlayer.dart';
import 'package:jellyfinity/features/playback/presentation/QueuePage.dart';

import '../../support/download_fakes.dart';
import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/pump_app.dart';
import '../../support/settings_fakes.dart';

Track _track(String itemId, {String name = 'Track'}) => Track(
  id: MediaId(serverId: 's1', itemId: itemId),
  name: name,
  artists: const [ArtistRef(name: 'Miles Davis')],
  duration: const Duration(minutes: 3),
);

class _NoArtworkUrl implements ArtworkResolver {
  @override
  Uri? imageUrl(MediaImage image, {int? maxWidth, int? maxHeight}) => null;
}

void main() {
  testWidgets('shared backdrop follows song changes and remains while paused', (
    tester,
  ) async {
    final playback = fakePlaybackCubit();
    final scope = await pumpApp(tester, playback: playback);
    getIt.registerSingleton<ArtworkResolver>(_NoArtworkUrl());
    await scope.signIn();
    await tester.pumpAndSettle();
    final first = MediaImage(
      itemId: mediaId('a'),
      kind: MediaImageKind.primary,
      tag: 'a',
    );
    final second = MediaImage(
      itemId: mediaId('b'),
      kind: MediaImageKind.primary,
      tag: 'b',
    );
    await playback.playNow([
      Track(id: mediaId('a'), name: 'First', image: first),
      Track(id: mediaId('b'), name: 'Second', image: second),
    ], startIndex: 0);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ArtworkBackground>(find.byType(ArtworkBackground).first)
          .image,
      first,
    );
    await playback.togglePlayPause();
    await tester.pumpAndSettle();
    await playback.next();
    await tester.pumpAndSettle();
    if (playback.state.isPlaying) await playback.togglePlayPause();
    await tester.pumpAndSettle();
    expect(playback.state.isPlaying, isFalse);
    expect(
      tester
          .widget<ArtworkBackground>(find.byType(ArtworkBackground).first)
          .image,
      second,
    );
    for (final scaffold in tester.widgetList<Scaffold>(find.byType(Scaffold))) {
      expect(scaffold.backgroundColor, Colors.transparent);
    }
  });
  testWidgets('wide player gives the cover room beside the controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();
    await playback.playNow([_track('a', name: 'Wide player')], startIndex: 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wide player'));
    await tester.pumpAndSettle();
    final art = find.byType(MediaArtwork).last;
    final controls = find.byIcon(Icons.pause_circle_filled_rounded);
    expect(tester.getSize(art).width, greaterThan(500));
    expect(
      tester.getCenter(controls).dx,
      greaterThan(tester.getRect(art).right),
    );
    expect(tester.takeException(), isNull);
    await playback.togglePlayPause();
  });
  setUp(() {
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  testWidgets('the mini-player is absent until something plays', (
    tester,
  ) async {
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.pause_rounded), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('shows the current track and toggles play/pause', (tester) async {
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
    await tester.pumpAndSettle();

    expect(find.text('So What'), findsOneWidget);
    expect(tester.getSize(find.byType(MiniPlayer)).height, MiniPlayer.height);
    expect(tester.takeException(), isNull);
    expect(
      find.byIcon(Icons.pause_rounded),
      findsOneWidget,
      reason: 'playNow starts playback',
    );

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('tapping the mini-player opens Now Playing', (tester) async {
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await playback.playNow([
      _track('a', name: 'So What'),
      _track('b', name: 'Freddie Freeloader'),
    ], startIndex: 0);
    await tester.pumpAndSettle();

    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);

    // Leave playback paused so no position-save timer outlives the test.
    await playback.togglePlayPause();
  });

  testWidgets('Now Playing controls remain usable in a short desktop window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 440));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();
    await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byIcon(Icons.pause_circle_filled_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.pause_circle_filled_rounded));
    await tester.pumpAndSettle();
    expect(playback.state.isPlaying, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shuffle and repeat toggle from Now Playing', (tester) async {
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await playback.playNow([
      _track('a', name: 'So What'),
      _track('b', name: 'Freddie Freeloader'),
    ], startIndex: 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();

    expect(playback.state.queue.shuffleEnabled, isFalse);
    await tester.tap(find.byIcon(Icons.shuffle_rounded));
    await tester.pumpAndSettle();
    expect(playback.state.queue.shuffleEnabled, isTrue);

    expect(playback.state.queue.repeatMode, RepeatMode.off);
    await tester.tap(find.byIcon(Icons.repeat_rounded));
    await tester.pumpAndSettle();
    expect(playback.state.queue.repeatMode, RepeatMode.all);

    await playback.togglePlayPause();
  });

  group('Now Playing details (v0.1.6)', () {
    testWidgets('the heart toggles the favorite state on the server', (
      tester,
    ) async {
      final track = Track(
        id: const MediaId(serverId: 's1', itemId: 'a'),
        name: 'So What',
        duration: const Duration(minutes: 3),
      );
      final favorites = FakeFavoritesRepository();
      registerNowPlayingDetailsCubit(
        metadata: FakeMediaMetadataRepository()..items = [track],
      );
      registerFavoritesRepository(favorites: favorites);

      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final scope = await pumpApp(tester, playback: playback);
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([track], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(favorites.calls.single.id, track.id);
      expect(favorites.calls.single.favorite, isTrue);

      await playback.togglePlayPause();
    });

    testWidgets('Now Playing offers to keep the track offline (v0.3.6)', (
      tester,
    ) async {
      final track = Track(
        id: const MediaId(serverId: 's1', itemId: 'a'),
        name: 'So What',
        duration: const Duration(minutes: 3),
      );
      registerNowPlayingDetailsCubit(
        metadata: FakeMediaMetadataRepository()..items = [track],
      );

      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final downloads = fakeDownloadsCubit();
      addTearDown(downloads.close);
      await downloads.restore();
      final scope = await pumpApp(
        tester,
        playback: playback,
        downloads: downloads,
      );
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([track], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();

      // The same download control every track row carries, on the player.
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);

      await playback.togglePlayPause();
    });

    testWidgets('the artist name opens that artist\'s page', (tester) async {
      const artistId = MediaId(serverId: 's1', itemId: 'artist-1');
      final track = Track(
        id: const MediaId(serverId: 's1', itemId: 'a'),
        name: 'So What',
        artists: const [ArtistRef(name: 'Miles Davis', id: artistId)],
        duration: const Duration(minutes: 3),
      );
      registerNowPlayingDetailsCubit(
        metadata: FakeMediaMetadataRepository()..items = [track],
      );
      registerMusicCubits(
        music: FakeMusicLibraryRepository()
          ..artistList = [const Artist(id: artistId, name: 'Miles Davis')],
      );

      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final scope = await pumpApp(tester, playback: playback);
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([track], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Miles Davis'));
      await tester.pumpAndSettle();

      expect(find.byType(ArtistDetailPage), findsOneWidget);

      await playback.togglePlayPause();
    });

    testWidgets(
      'falls back to plain, unlinked text before the track record loads',
      (tester) async {
        final playback = fakePlaybackCubit();
        addTearDown(playback.close);
        final scope = await pumpApp(tester, playback: playback);
        await scope.signIn();
        await tester.pumpAndSettle();

        await playback.playNow([
          Track(
            id: const MediaId(serverId: 's1', itemId: 'a'),
            name: 'So What',
            artists: const [ArtistRef(name: 'Miles Davis')],
            duration: const Duration(minutes: 3),
          ),
        ], startIndex: 0);
        await tester.pumpAndSettle();
        await tester.tap(find.text('So What'));
        await tester.pumpAndSettle();

        // No favorite heart without a resolved track record, and the
        // credit with no artist id is not a link either way.
        expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
        expect(find.text('Miles Davis'), findsOneWidget);

        await playback.togglePlayPause();
      },
    );
  });

  testWidgets('the queue editor opens over Now Playing and dismisses', (
    tester,
  ) async {
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await playback.playNow([
      _track('a', name: 'So What'),
      _track('b', name: 'Freddie Freeloader'),
    ], startIndex: 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();

    final queueButton = find.byTooltip('Edit queue');
    expect(tester.getSize(queueButton), const Size(56, 56));
    await tester.tap(queueButton);
    await tester.pumpAndSettle();

    expect(find.byType(QueueEditor), findsOneWidget);
    expect(find.text('Edit queue'), findsOneWidget);
    expect(find.text('Freddie Freeloader'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(QueueEditor), findsNothing);

    await tester.tap(queueButton);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 200));
    await tester.pumpAndSettle();
    expect(find.byType(QueueEditor), findsNothing);

    await playback.togglePlayPause();
  });

  testWidgets('the queue screen lists entries and removes one', (tester) async {
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await playback.playNow([
      _track('a', name: 'So What'),
      _track('b', name: 'Freddie Freeloader'),
    ], startIndex: 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    expect(find.byType(QueuePage), findsOneWidget);
    expect(find.text('So What'), findsOneWidget);
    expect(find.text('Freddie Freeloader'), findsOneWidget);
    // The total runtime header (v0.1.6): both 3-minute tracks, from now on.
    expect(find.text('2 songs · 6 min left'), findsOneWidget);
    // A drag handle per row (v0.1.6), not a whole-row long-press.
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('Freddie Freeloader'), findsNothing);
    expect(playback.state.queue.entries, hasLength(1));

    await playback.togglePlayPause();
  });

  /// Opens Now Playing's Queue screen for a queue already loaded into
  /// [playback] — the same three taps every queue test starts with.
  Future<void> openQueueScreen(WidgetTester tester, String currentTitle) async {
    await tester.tap(find.text(currentTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();
  }

  testWidgets('the queue screen lists rows in the order they will actually '
      'play (v0.4.1)', (tester) async {
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await playback.playNow([
      _track('a', name: 'So What'),
      _track('b', name: 'Blue in Green'),
      _track('c', name: 'Flamenco Sketches'),
    ], startIndex: 0);
    await tester.pumpAndSettle();
    // Not awaited: a queue edit reloads the engine playlist, and that
    // reload waits on a timer only `pump` advances. Started, then pumped.
    unawaited(playback.toggleShuffle());
    await tester.pumpAndSettle();
    unawaited(playback.reorderPlayOrder(1, 2));
    await tester.pumpAndSettle();

    await openQueueScreen(tester, 'So What');

    final order = playback.state.queue.playOrder
        .map((i) => playback.state.queue.entries[i].title)
        .toList();
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where(order.contains)
        .toList();
    expect(
      shown,
      order,
      reason: 'the list called "up next" is what comes next',
    );

    await playback.togglePlayPause();
  });

  testWidgets('the queue screen says when nothing follows the last track '
      '(v0.4.1)', (tester) async {
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await playback.playNow([
      _track('a', name: 'So What'),
      _track('b', name: 'Blue in Green'),
    ], startIndex: 1);
    await tester.pumpAndSettle();

    await openQueueScreen(tester, 'Blue in Green');
    expect(find.text('End of queue'), findsOneWidget);

    // Repeat all means there is always something after it.
    unawaited(playback.setRepeatMode(RepeatMode.all));
    await tester.pumpAndSettle();
    expect(find.text('End of queue'), findsNothing);

    await playback.togglePlayPause();
  });

  testWidgets('a failed queue row explains itself and offers a retry '
      '(v0.4.1)', (tester) async {
    final engine = FakePlaybackEngine();
    final playback = fakePlaybackCubit(engine: engine);
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await playback.playNow([
      _track('a', name: 'So What'),
      _track('b', name: 'Blue in Green'),
    ], startIndex: 0);
    await tester.pumpAndSettle();
    await openQueueScreen(tester, 'So What');

    // Twice: the first failure buys a re-resolve (v0.4.1).
    for (var i = 0; i < 2; i++) {
      engine.emitFailure(
        const PlaybackFailure(
          sourceIndex: 1,
          id: MediaId(serverId: 's1', itemId: 'b'),
          message: 'The stream ended.',
        ),
      );
      await tester.pumpAndSettle();
    }

    expect(
      find.text('The stream ended. Tap to try again.'),
      findsOneWidget,
      reason: 'unavailable on its own is not an explanation',
    );

    await playback.togglePlayPause();
  });

  testWidgets('clearing the queue empties it', (tester) async {
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await playback.playNow([
      _track('a', name: 'So What'),
      _track('b', name: 'Freddie Freeloader'),
    ], startIndex: 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pumpAndSettle();

    // A confirmation prompt stands between the icon and actually
    // clearing the queue (v0.1.6).
    expect(
      find.text('Do you want to remove all items from the queue?'),
      findsOneWidget,
    );
    expect(playback.state.queue.isEmpty, isFalse);

    await tester.tap(find.text('Remove all'));
    await tester.pumpAndSettle();

    expect(playback.state.queue.isEmpty, isTrue);
    expect(find.text('The queue is empty'), findsOneWidget);
  });

  testWidgets('cancelling the clear-queue prompt leaves it untouched', (
    tester,
  ) async {
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await playback.playNow([
      _track('a', name: 'So What'),
      _track('b', name: 'Freddie Freeloader'),
    ], startIndex: 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(playback.state.queue.entries, hasLength(2));

    await playback.togglePlayPause();
  });

  testWidgets('an empty queue screen shows the empty state', (tester) async {
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('The queue is empty'), findsOneWidget);
  });

  testWidgets('the queue reorders under a mouse drag, for Windows '
      '(v0.4.1)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await playback.playNow([
      _track('a', name: 'So What'),
      _track('b', name: 'Blue in Green'),
      _track('c', name: 'Flamenco Sketches'),
    ], startIndex: 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    // A pointer press on the drag handle, not a touch long-press: on
    // Windows the handle is the whole reorder affordance.
    final handles = find.byIcon(Icons.drag_indicator_rounded);
    final from = tester.getCenter(handles.at(2));
    final to = tester.getCenter(handles.at(1));
    final mouse = await tester.startGesture(
      from,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(kLongPressTimeout);
    await mouse.moveTo(to);
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();

    final order = [
      for (final i in playback.state.queue.playOrder)
        playback.state.queue.entries[i].title,
    ];
    expect(order, ['So What', 'Flamenco Sketches', 'Blue in Green']);

    await playback.togglePlayPause();
  });

  group('what is really happening to this track (v0.4.1)', () {
    testWidgets('says when normalization has no loudness data to use', (
      tester,
    ) async {
      final settings = fakeSettingsCubit(
        normalization: const NormalizationSettings(enabled: true),
      );
      addTearDown(settings.close);
      final playback = fakePlaybackCubit(settings: settings);
      addTearDown(playback.close);
      final scope = await pumpApp(
        tester,
        playback: playback,
        settings: settings,
      );
      await scope.signIn();
      await tester.pumpAndSettle();

      // `_track` builds a track with no `normalizationGain` — the server
      // never analyzed it, so the setting has nothing to apply.
      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('no loudness data'),
        findsOneWidget,
        reason: 'a feature that cannot apply says so instead of going quiet',
      );

      await playback.togglePlayPause();
    });

    testWidgets('says nothing when normalization has a gain to apply', (
      tester,
    ) async {
      final settings = fakeSettingsCubit(
        normalization: const NormalizationSettings(enabled: true),
      );
      addTearDown(settings.close);
      final playback = fakePlaybackCubit(settings: settings);
      addTearDown(playback.close);
      final scope = await pumpApp(
        tester,
        playback: playback,
        settings: settings,
      );
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([
        Track(
          id: mediaId('a'),
          name: 'So What',
          duration: const Duration(minutes: 3),
          normalizationGain: -6.5,
        ),
      ], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no loudness data'), findsNothing);

      await playback.togglePlayPause();
    });

    testWidgets('says why crossfade is not happening under repeat one', (
      tester,
    ) async {
      final settings = fakeSettingsCubit(
        crossfade: const CrossfadeSettings(
          enabled: true,
          duration: Duration(seconds: 6),
        ),
      );
      addTearDown(settings.close);
      final playback = fakePlaybackCubit(settings: settings);
      addTearDown(playback.close);
      final scope = await pumpApp(
        tester,
        playback: playback,
        settings: settings,
      );
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([
        _track('a', name: 'So What'),
        _track('b', name: 'Blue in Green'),
      ], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Crossfade is paused'), findsNothing);

      unawaited(playback.setRepeatMode(RepeatMode.one));
      await tester.pumpAndSettle();

      expect(find.textContaining('Crossfade is paused'), findsOneWidget);

      await playback.togglePlayPause();
    });
  });

  group('streaming quality hint (ADR-0015)', () {
    testWidgets('shows the source file format and bitrate', (tester) async {
      final settings = fakeSettingsCubit();
      addTearDown(settings.close);
      final playback = fakePlaybackCubit(settings: settings);
      addTearDown(playback.close);
      final resolver = FakeTrackSourceInfoResolver()
        ..answer = (_) =>
            const Result.ok(TrackSourceInfo(codec: 'flac', bitrateBps: 995000));
      final scope = await pumpApp(
        tester,
        playback: playback,
        settings: settings,
        trackSourceInfoResolver: resolver,
      );
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();

      expect(find.textContaining('FLAC'), findsOneWidget);
      expect(find.textContaining('995 kbps'), findsOneWidget);

      await playback.togglePlayPause();
    });

    testWidgets(
      'marks a transcoded stream with its target format and bitrate',
      (tester) async {
        final settings = fakeSettingsCubit(quality: StreamQuality.medium);
        addTearDown(settings.close);
        final playback = fakePlaybackCubit(settings: settings);
        addTearDown(playback.close);
        final resolver = FakeTrackSourceInfoResolver()
          ..answer = (_) => const Result.ok(
            TrackSourceInfo(codec: 'flac', bitrateBps: 995000),
          );
        final scope = await pumpApp(
          tester,
          playback: playback,
          settings: settings,
          trackSourceInfoResolver: resolver,
        );
        await scope.signIn();
        await tester.pumpAndSettle();

        await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
        await tester.pumpAndSettle();
        await tester.tap(find.text('So What'));
        await tester.pumpAndSettle();

        // The v0.1.6 badge names the transcode target instead of a
        // "Transcoding to..." sentence.
        expect(find.textContaining('AAC · 192 kbps'), findsOneWidget);

        await playback.togglePlayPause();
      },
    );

    testWidgets('shows nothing extra when source details are unavailable', (
      tester,
    ) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final scope = await pumpApp(tester, playback: playback);
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();

      expect(find.textContaining('kbps'), findsNothing);

      await playback.togglePlayPause();
    });
  });

  group('lyrics (v0.1.5)', () {
    testWidgets('shows plain lyrics with no timing', (tester) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final resolver = FakeLyricsResolver()
        ..answer = (_) => const Result.ok(
          Lyrics(
            lines: [
              LyricLine(text: 'First line'),
              LyricLine(text: 'Second line'),
            ],
            isSynchronized: false,
          ),
        );
      final scope = await pumpApp(
        tester,
        playback: playback,
        lyricsResolver: resolver,
      );
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lyrics'));
      await tester.pumpAndSettle();

      expect(find.byType(LyricsPage), findsOneWidget);
      expect(find.text('First line'), findsOneWidget);
      expect(find.text('Second line'), findsOneWidget);

      await playback.togglePlayPause();
    });

    testWidgets('shows the empty state for a track with no lyrics', (
      tester,
    ) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final scope = await pumpApp(tester, playback: playback);
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lyrics'));
      await tester.pumpAndSettle();

      expect(find.text('No lyrics available'), findsOneWidget);

      await playback.togglePlayPause();
    });

    testWidgets('shows a retryable error and recovers', (tester) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      var attempt = 0;
      final resolver = FakeLyricsResolver()
        ..answer = (_) {
          attempt += 1;
          if (attempt == 1) {
            return const Result.err(
              RecoverableFailure('The server took too long to respond.'),
            );
          }
          return const Result.ok(
            Lyrics(
              lines: [LyricLine(text: 'First line')],
              isSynchronized: false,
            ),
          );
        };
      final scope = await pumpApp(
        tester,
        playback: playback,
        lyricsResolver: resolver,
      );
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lyrics'));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('First line'), findsOneWidget);

      await playback.togglePlayPause();
    });

    testWidgets('highlights the current line for synchronized lyrics', (
      tester,
    ) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final resolver = FakeLyricsResolver()
        ..answer = (_) => const Result.ok(
          Lyrics(
            lines: [
              LyricLine(text: 'Line A', start: Duration.zero),
              LyricLine(text: 'Line B', start: Duration(seconds: 5)),
            ],
            isSynchronized: true,
          ),
        );
      final scope = await pumpApp(
        tester,
        playback: playback,
        lyricsResolver: resolver,
      );
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lyrics'));
      await tester.pumpAndSettle();

      Color colorOf(String text) =>
          tester.widget<Text>(find.text(text)).style!.color!;

      expect(colorOf('Line A'), isNot(colorOf('Line B')));
      final firstActiveColor = colorOf('Line A');

      await playback.seek(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(colorOf('Line B'), firstActiveColor);
      expect(colorOf('Line A'), isNot(firstActiveColor));

      await playback.togglePlayPause();
    });
  });
}
