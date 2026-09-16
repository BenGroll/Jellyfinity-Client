import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/PlaybackControlCubit.dart';
import 'package:jellyfinity/app/di/service_locator.dart';
import 'package:jellyfinity/app/connected_playback/ConnectedPlaybackScopeOf.dart';
import 'package:jellyfinity/domain/connected_playback/SyncPlayGroupUpdate.dart';
import 'package:jellyfinity/domain/connected_playback/device_reachability.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';

import '../../support/connected_playback/FakeDevicePresenceSource.dart';
import '../../support/connected_playback/FakeSyncPlayTransport.dart';
import '../../support/connected_playback/connected_playback_fixtures.dart'
    show device;
import '../../support/media_fakes.dart' show FakeArtworkResolver;
import '../../support/playback_fakes.dart';
import '../../support/pump_app.dart';

Track _track(String itemId, {String name = 'Track'}) => Track(
  id: MediaId(serverId: 's1', itemId: itemId),
  name: name,
  duration: const Duration(minutes: 3),
);

Future<void> _openRemote(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Remote'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  testWidgets('Remote is reachable from the shell and lists this device', (
    tester,
  ) async {
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    final scope = await pumpApp(tester, playback: playback);
    await scope.signIn();
    await tester.pumpAndSettle();

    await _openRemote(tester);

    expect(find.text('This device'), findsOneWidget);
    expect(
      find.text('No other Jellyfinity devices found on this server yet.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows a reachable peer and offers to bring paused local playback back',
    (tester) async {
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
          name: 'Living Room TV',
          nowPlayingTitle: 'So What',
          nowPlayingArtist: 'Miles Davis',
        ),
      ]);
      await tester.pumpAndSettle();

      await _openRemote(tester);

      expect(find.text('Living Room TV'), findsOneWidget);
      expect(find.text('Miles Davis • So What'), findsOneWidget);
      expect(find.text('Paused here — tap to bring it back'), findsOneWidget);
    },
  );

  testWidgets("a peer's box shows its own album art, not a generic icon", (
    tester,
  ) async {
    final presence = FakeDevicePresenceSource();
    final playback = fakePlaybackCubit();
    addTearDown(playback.close);
    if (!getIt.isRegistered<ArtworkResolver>()) {
      getIt.registerLazySingleton<ArtworkResolver>(FakeArtworkResolver.new);
    }
    final scope = await pumpApp(
      tester,
      playback: playback,
      devicePresence: presence,
    );
    await scope.signIn();
    await tester.pumpAndSettle();

    final playbackScope = connectedPlaybackScopeOf(scope.cubit.state)!;
    final art = MediaImage(
      itemId: MediaId(serverId: playbackScope.serverId, itemId: 'track-1'),
      kind: MediaImageKind.primary,
      tag: 'tag-1',
    );
    presence.emitDevices(playbackScope, [
      device(
        scope: playbackScope,
        sessionId: 'session-tv',
        name: 'Living Room TV',
        nowPlayingTitle: 'So What',
        nowPlayingArtist: 'Miles Davis',
        nowPlayingImage: art,
      ),
    ]);
    await tester.pumpAndSettle();

    await _openRemote(tester);

    final artwork = tester.widget<MediaArtwork>(find.byType(MediaArtwork));
    expect(artwork.image, art);
    expect(find.byIcon(Icons.speaker_rounded), findsNothing);
  });

  testWidgets('bringing local playback back detaches active remote control', (
    tester,
  ) async {
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
    final playbackScope = connectedPlaybackScopeOf(scope.cubit.state)!;
    presence.emitDevices(playbackScope, [
      device(scope: playbackScope, sessionId: 'session-tv'),
    ]);
    final control = getIt<PlaybackControlCubit>();
    control.emit(
      PlaybackControlState(
        device: device(scope: playbackScope, sessionId: 'session-tv'),
      ),
    );
    await tester.pumpAndSettle();

    await _openRemote(tester);
    await tester.tap(find.text('This device'));
    await tester.pumpAndSettle();

    expect(control.state.device, isNull);
    expect(playback.state.isPlaying, isTrue);
    await playback.pause();
  });

  testWidgets('the Remote list omits stale peers', (tester) async {
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

    final playbackScope = connectedPlaybackScopeOf(scope.cubit.state)!;
    presence.emitDevices(playbackScope, [
      device(
        scope: playbackScope,
        sessionId: 'session-stale',
        name: 'Old Laptop',
        reachability: DeviceReachability.stale,
      ),
    ]);
    await _openRemote(tester);

    expect(find.text('Old Laptop'), findsNothing);
    expect(
      find.text('No other Jellyfinity devices found on this server yet.'),
      findsOneWidget,
    );
  });

  group('play on all devices (v0.6.0, ADR-0045)', () {
    testWidgets(
      'is disabled with nothing playing here, and starts a group once '
      'tapped with something playing',
      (tester) async {
        final playback = fakePlaybackCubit();
        addTearDown(playback.close);
        final transport = FakeSyncPlayTransport();
        final scope = await pumpApp(
          tester,
          playback: playback,
          syncPlayTransport: transport,
        );
        await scope.signIn();
        await tester.pumpAndSettle();
        await _openRemote(tester);

        final button = find.widgetWithText(TextButton, 'Play on all devices');
        expect(tester.widget<TextButton>(button).onPressed, isNull);

        await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
        await tester.pumpAndSettle();

        expect(tester.widget<TextButton>(button).onPressed, isNotNull);
        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(transport.calls, contains('createGroup'));
        expect(find.text('Starting a group…'), findsOneWidget);

        transport.emit(
          const SyncPlayGroupJoined(
            groupId: 'group-1',
            groupName: 'Living Room',
            members: [],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Playing on all devices'), findsOneWidget);
        expect(
          find.text('In "Living Room", playing here for now.'),
          findsOneWidget,
        );

        await playback.pause();
      },
    );

    testWidgets('a denied join shows an honest reason, not a silent '
        'no-op', (tester) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final transport = FakeSyncPlayTransport();
      final scope = await pumpApp(
        tester,
        playback: playback,
        syncPlayTransport: transport,
      );
      await scope.signIn();
      await tester.pumpAndSettle();
      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await tester.pumpAndSettle();

      await _openRemote(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Play on all devices'));
      await tester.pumpAndSettle();

      transport.emit(
        const SyncPlayJoinDenied('SyncPlay is disabled on this server.'),
      );
      await tester.pumpAndSettle();

      expect(find.text('SyncPlay is disabled on this server.'), findsOneWidget);

      await playback.pause();
    });

    testWidgets('leaving returns to the ordinary single-device state', (
      tester,
    ) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final transport = FakeSyncPlayTransport();
      final scope = await pumpApp(
        tester,
        playback: playback,
        syncPlayTransport: transport,
      );
      await scope.signIn();
      await tester.pumpAndSettle();
      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await tester.pumpAndSettle();

      await _openRemote(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Play on all devices'));
      transport.emit(
        const SyncPlayGroupJoined(
          groupId: 'group-1',
          groupName: 'Living Room',
          members: [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Leave'));
      await tester.pumpAndSettle();

      expect(transport.calls, contains('leaveGroup'));
      expect(find.text('Play on all devices'), findsOneWidget);

      await playback.pause();
    });
  });
}
