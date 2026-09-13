import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/ConnectedPlaybackScopeOf.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/domain/connected_playback/device_reachability.dart';
import 'package:jellyfinity/domain/media/media.dart';

import '../../support/connected_playback/FakeDevicePresenceSource.dart';
import '../../support/connected_playback/connected_playback_fixtures.dart'
    show device;
import '../../support/playback_fakes.dart';
import '../../support/pump_app.dart';

Track _track(String itemId, {String name = 'Track'}) => Track(
  id: MediaId(serverId: 's1', itemId: itemId),
  name: name,
  duration: const Duration(minutes: 3),
);

void main() {
  group('the device action', () {
    testWidgets('is absent until something plays', (tester) async {
      final scope = await pumpApp(tester, playback: fakePlaybackCubit());
      await scope.signIn();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cast_rounded), findsNothing);
    });

    testWidgets('opens the picker from the mini-player, showing this '
        'device as the one playing and no other devices found', (tester) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final scope = await pumpApp(tester, playback: playback);
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cast_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.cast_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Devices'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);
      expect(find.text('Playing here'), findsOneWidget);
      expect(
        find.text('No other Jellyfinity devices found on this server yet.'),
        findsOneWidget,
      );

      // Leave playback paused so no position-save timer outlives the test.
      await playback.pause();
    });

    testWidgets('opens the same picker from Now Playing', (tester) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final scope = await pumpApp(tester, playback: playback);
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cast_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.cast_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Devices'), findsOneWidget);

      // Leave playback paused so no position-save timer outlives the test.
      await playback.pause();
    });

    testWidgets('lists a remote device with its capability-limited '
        'reason, and offers to bring paused local playback back once '
        'the queue is not playing', (tester) async {
      final presence = FakeDevicePresenceSource();
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final scope = await pumpApp(
        tester,
        playback: playback,
        devicePresence: presence,
      );
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await playback.pause();
      await tester.pumpAndSettle();

      final playbackScope = connectedPlaybackScopeOf(scope.cubit.state)!;
      presence.emitDevices(playbackScope, [
        device(
          scope: playbackScope,
          sessionId: 'session-tv',
          name: 'Living Room',
          reachability: DeviceReachability.stale,
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.cast_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Living Room'), findsOneWidget);
      expect(find.text('Not seen recently'), findsOneWidget);
      expect(find.text('Paused here — tap to bring it back'), findsOneWidget);

      await tester.tap(find.text('This device'));
      await tester.pumpAndSettle();

      expect(playback.state.isPlaying, isTrue);

      // Leave playback paused so no position-save timer outlives the test.
      await playback.pause();
    });
  });

  group('the device picker at different constraints', () {
    Future<void> openPicker(WidgetTester tester, PlaybackCubit playback) async {
      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.cast_rounded));
      await tester.pumpAndSettle();
    }

    testWidgets('renders without overflow at compact phone width', (
      tester,
    ) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final scope = await pumpApp(
        tester,
        playback: playback,
        viewportSize: const Size(360, 720),
      );
      await scope.signIn();
      await tester.pumpAndSettle();
      await openPicker(tester, playback);

      expect(tester.takeException(), isNull);
      expect(find.text('Devices'), findsOneWidget);

      // Leave playback paused so no position-save timer outlives the test.
      await playback.pause();
    });

    testWidgets('renders without overflow in a windowed desktop width', (
      tester,
    ) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final scope = await pumpApp(
        tester,
        playback: playback,
        viewportSize: const Size(1280, 800),
      );
      await scope.signIn();
      await tester.pumpAndSettle();
      await openPicker(tester, playback);

      expect(tester.takeException(), isNull);
      expect(find.text('Devices'), findsOneWidget);

      // Leave playback paused so no position-save timer outlives the test.
      await playback.pause();
    });

    testWidgets('renders without overflow at television scale', (tester) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final scope = await pumpApp(
        tester,
        playback: playback,
        televisionMode: true,
        viewportSize: const Size(1920, 1080),
      );
      await scope.signIn();
      await tester.pumpAndSettle();
      await openPicker(tester, playback);

      expect(tester.takeException(), isNull);
      expect(find.text('Devices'), findsOneWidget);

      // Leave playback paused so no position-save timer outlives the test.
      await playback.pause();
    });
  });
}
