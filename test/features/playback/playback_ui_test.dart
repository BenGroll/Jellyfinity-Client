import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';
import 'package:jellyfinity/features/playback/presentation/QueuePage.dart';

import '../../support/playback_fakes.dart';
import '../../support/pump_app.dart';

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

    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('Freddie Freeloader'), findsNothing);
    expect(playback.state.queue.entries, hasLength(1));

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
}
