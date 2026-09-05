import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/domain/playback/Lyrics.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';
import 'package:jellyfinity/domain/playback/stream_quality.dart';
import 'package:jellyfinity/domain/playback/TrackSourceInfo.dart';
import 'package:jellyfinity/features/music/presentation/detail/ArtistDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';
import 'package:jellyfinity/features/playback/presentation/LyricsPage.dart';
import 'package:jellyfinity/features/playback/presentation/QueuePage.dart';

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

void main() {
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

    await tester.tap(find.byIcon(Icons.queue_music_rounded));
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
    await tester.tap(find.byIcon(Icons.queue_music_rounded));
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
    await tester.tap(find.byIcon(Icons.queue_music_rounded));
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
    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('The queue is empty'), findsOneWidget);
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

      await tester.tap(find.byIcon(Icons.lyrics_outlined));
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

      await tester.tap(find.byIcon(Icons.lyrics_outlined));
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
      await tester.tap(find.byIcon(Icons.lyrics_outlined));
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
      await tester.tap(find.byIcon(Icons.lyrics_outlined));
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
