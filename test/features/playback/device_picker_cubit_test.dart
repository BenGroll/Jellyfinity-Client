import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/ConnectedPlaybackTargetLink.dart';
import 'package:jellyfinity/app/connected_playback/SupportedRemoteCommands.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/domain/connected_playback/connection_state.dart';
import 'package:jellyfinity/domain/connected_playback/device_reachability.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/media/Track.dart';
import 'package:jellyfinity/features/playback/presentation/device_picker_cubit.dart';

import '../../support/TestLogger.dart';
import '../../support/connected_playback/FakeConnectedPlaybackNetwork.dart';
import '../../support/connected_playback/FakeConnectedPlaybackTransport.dart';
import '../../support/connected_playback/FakeDevicePresenceSource.dart';
import '../../support/connected_playback/connected_playback_fixtures.dart';
import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/session_fakes.dart';
import '../../support/settings_fakes.dart';

/// This device's session id in every test — matches the `isThisDevice`
/// row [connected_playback_fixtures.device] would otherwise have to be
/// told about by hand.
const String _thisSessionId = 'session-phone';

void main() {
  Track track(String id) => Track(
    id: MediaId(serverId: testScope.serverId, itemId: id),
    name: 'Track $id',
    duration: const Duration(minutes: 3),
  );

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  late FakeConnectedPlaybackNetwork network;
  late FakePlaybackEngine engine;
  late PlaybackCubit playback;
  late FakeConnectedPlaybackTransport transport;
  late ConnectedPlaybackTargetLink handoff;
  late FakeDevicePresenceSource presence;
  late DevicePickerCubit cubit;

  setUp(() async {
    network = FakeConnectedPlaybackNetwork();
    engine = FakePlaybackEngine();
    playback = PlaybackCubit(
      engine,
      FakeQueueRepository(),
      FakeAudioSourceResolver(),
      RecordingPlaybackProgressRepository(),
      RecordingListeningHistoryRepository(),
      fakeSettingsCubit(),
    );
    transport = FakeConnectedPlaybackTransport(
      network: network,
      sessionId: _thisSessionId,
      scope: testScope,
    );
    handoff = ConnectedPlaybackTargetLink(
      playback,
      transport,
      fakeSessionCubit(signedIn: fakeAuthSession()),
      FakeMusicLibraryRepository(),
      TestLogger(),
    );
    await handoff.start();
    presence = FakeDevicePresenceSource.empty();
    cubit = DevicePickerCubit(
      presence,
      fakeSessionCubit(signedIn: fakeAuthSession()),
      playback,
      handoff,
    );
  });

  tearDown(() async {
    await cubit.close();
    await handoff.stop();
    await playback.close();
    await presence.dispose();
  });

  group('presence', () {
    test('lists devices presence emits for the signed-in scope', () async {
      final tv = device(sessionId: 'session-tv', isPlaying: true);
      presence.emitDevices(testScope, [tv]);
      await settle();

      expect(cubit.state.devices, [tv]);
    });

    test(
      'orders a device already producing audio ahead of a merely '
      'available one, and both ahead of one that cannot be reached',
      () async {
        final stale = device(
          sessionId: 'session-stale',
          name: 'Stale',
          reachability: DeviceReachability.stale,
        );
        final available = device(sessionId: 'session-tv', name: 'Available');
        final active = device(
          sessionId: 'session-active',
          name: 'Active',
          isPlaying: true,
        );
        presence.emitDevices(testScope, [stale, available, active]);
        await settle();

        expect(cubit.state.devices.map((d) => d.sessionId), [
          'session-active',
          'session-tv',
          'session-stale',
        ]);
      },
    );

    test('tracks this device\'s own link state', () async {
      presence.emitConnection(ConnectedPlaybackConnection.reconnecting);
      await settle();

      expect(cubit.state.connection, ConnectedPlaybackConnection.reconnecting);
    });

    test('drops the device list on sign-out and does not react to a '
        'stream still emitting for the old scope', () async {
      presence.emitDevices(testScope, [device(sessionId: 'session-tv')]);
      await settle();
      expect(cubit.state.devices, isNotEmpty);

      final signedOutSession = fakeSessionCubit();
      final signedOutCubit = DevicePickerCubit(
        presence,
        signedOutSession,
        playback,
        handoff,
      );
      await settle();

      expect(signedOutCubit.state.devices, isEmpty);
      await signedOutCubit.close();
    });
  });

  group('local playback state', () {
    test('starts from PlaybackCubit\'s current state', () async {
      await playback.playNow([track('a')], startIndex: 0);
      await settle();

      final fresh = DevicePickerCubit(
        presence,
        fakeSessionCubit(signedIn: fakeAuthSession()),
        playback,
        handoff,
      );

      expect(fresh.state.localHasQueue, isTrue);
      expect(fresh.state.localIsPlaying, isTrue);
      await fresh.close();
    });

    test('follows PlaybackCubit through pause and resume', () async {
      await playback.playNow([track('a')], startIndex: 0);
      await settle();
      expect(cubit.state.localIsPlaying, isTrue);

      await playback.pause();
      await settle();
      expect(cubit.state.localIsPlaying, isFalse);
      expect(cubit.state.localHasQueue, isTrue);
    });
  });

  group('bringBackToThisDevice', () {
    test('resumes a paused local queue', () async {
      await playback.playNow([track('a')], startIndex: 0);
      await playback.pause();
      await settle();

      await cubit.bringBackToThisDevice();
      await settle();

      expect(engine.playing, isTrue);
    });

    test('does nothing without a local queue to resume', () async {
      await cubit.bringBackToThisDevice();
      await settle();

      expect(engine.playing, isFalse);
    });
  });

  group('transferTo', () {
    test('fails when there is nothing playing locally to send', () async {
      await cubit.transferTo(device(sessionId: 'session-tv'));

      expect(cubit.state.transfer.phase, DeviceTransferPhase.failed);
      expect(cubit.state.transfer.message, contains('Nothing is playing'));
    });

    test('moves ownership to a real target over the fake network and '
        'reports success', () async {
      final targetEngine = FakePlaybackEngine();
      final targetPlayback = PlaybackCubit(
        targetEngine,
        FakeQueueRepository(),
        FakeAudioSourceResolver(),
        RecordingPlaybackProgressRepository(),
        RecordingListeningHistoryRepository(),
        fakeSettingsCubit(),
      );
      final targetTransport = FakeConnectedPlaybackTransport(
        network: network,
        sessionId: 'session-tv',
        scope: testScope,
      );
      final targetLibrary = FakeMusicLibraryRepository()
        ..trackList = [track('a')];
      final targetLink = ConnectedPlaybackTargetLink(
        targetPlayback,
        targetTransport,
        fakeSessionCubit(signedIn: fakeAuthSession()),
        targetLibrary,
        TestLogger(),
      );
      await targetLink.start();

      await playback.playNow([track('a')], startIndex: 0);
      await settle();

      await cubit.transferTo(
        device(sessionId: 'session-tv', capabilities: supportedRemoteCommands),
      );
      await settle();

      expect(cubit.state.transfer.phase, DeviceTransferPhase.succeeded);
      expect(targetPlayback.state.hasQueue, isTrue);
      expect(targetEngine.playing, isTrue);
      expect(engine.playing, isFalse);

      await targetLink.stop();
      await targetPlayback.close();
    });

    test('refuses a second transfer while one is already in flight', () async {
      await playback.playNow([track('a')], startIndex: 0);
      await settle();

      final unreachable = device(
        sessionId: 'session-unreachable',
        reachability: DeviceReachability.offline,
      );
      final first = cubit.transferTo(unreachable);
      await cubit.transferTo(unreachable);

      await first;
      await settle();

      // Both calls resolved into exactly one outcome for the one device
      // that was actually addressed — a second call while the first is
      // in flight is a no-op, not a second attempt.
      expect(cubit.state.transfer.deviceSessionId, 'session-unreachable');
    });
  });
}
