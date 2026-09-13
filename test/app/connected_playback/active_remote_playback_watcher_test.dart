import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/ActiveRemotePlaybackWatcher.dart';
import 'package:jellyfinity/app/connected_playback/PlaybackControlCubit.dart';
import 'package:jellyfinity/app/connected_playback/SupportedRemoteCommands.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedDevice.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceCapabilities.dart';
import 'package:jellyfinity/domain/connected_playback/device_reachability.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/media/Track.dart';

import '../../support/connected_playback/FakeConnectedPlaybackNetwork.dart';
import '../../support/connected_playback/FakeConnectedPlaybackTransport.dart';
import '../../support/connected_playback/FakeDevicePresenceSource.dart';
import '../../support/connected_playback/connected_playback_fixtures.dart';
import '../../support/playback_fakes.dart';
import '../../support/session_fakes.dart';
import '../../support/settings_fakes.dart';

/// v0.6.0's first requirement, as behaviour: opening Jellyfinity while
/// another of this profile's devices is playing shows that session,
/// without the listener opening a picker — and never against their will.
void main() {
  late FakeDevicePresenceSource presence;
  late FakeConnectedPlaybackTransport transport;
  late PlaybackCubit playback;
  late PlaybackControlCubit control;
  late ActiveRemotePlaybackWatcher watcher;

  Track track(String id) => Track(
    id: MediaId(serverId: testScope.serverId, itemId: id),
    name: 'Track $id',
    duration: const Duration(minutes: 3),
  );

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// A peer as the roster reports it while it is the one making noise.
  ConnectedDevice playingTv({
    String deviceId = 'device-tv',
    String sessionId = 'session-tv',
    String name = 'Living Room',
    DeviceReachability reachability = DeviceReachability.ready,
    DeviceCapabilities? capabilities,
  }) => device(
    deviceId: deviceId,
    sessionId: sessionId,
    name: name,
    reachability: reachability,
    capabilities: capabilities ?? supportedRemoteCommands,
    isPlaying: true,
  );

  setUp(() async {
    presence = FakeDevicePresenceSource.empty();
    transport = FakeConnectedPlaybackTransport(
      network: FakeConnectedPlaybackNetwork(),
      sessionId: 'session-phone',
      scope: testScope,
    );
    playback = PlaybackCubit(
      FakePlaybackEngine(),
      FakeQueueRepository(),
      FakeAudioSourceResolver(),
      RecordingPlaybackProgressRepository(),
      RecordingListeningHistoryRepository(),
      fakeSettingsCubit(),
    );
    control = PlaybackControlCubit(
      transport,
      presence,
      fakeSessionCubit(signedIn: fakeAuthSession()),
    );
    watcher = ActiveRemotePlaybackWatcher(
      presence,
      fakeSessionCubit(signedIn: fakeAuthSession()),
      playback,
      control,
    );
    await watcher.start();
    await settle();
  });

  tearDown(() async {
    await watcher.stop();
    await control.close();
    await playback.close();
    await presence.dispose();
  });

  test('binds to the one device that is already playing', () async {
    presence.emitDevices(testScope, [playingTv()]);
    await settle();

    expect(control.state.isControlling, isTrue);
    expect(control.state.device?.deviceId, 'device-tv');
  });

  test('leaves a device that is merely listed alone', () async {
    presence.emitDevices(testScope, [device()]);
    await settle();

    expect(control.state.isControlling, isFalse);
  });

  test('will not bind to a peer that has not advertised yet', () async {
    presence.emitDevices(testScope, [
      playingTv(reachability: DeviceReachability.presenceOnly),
    ]);
    await settle();

    // Presence-only means the server lists it and it has not said what it
    // accepts; binding a mini-player to it would offer controls that may
    // not exist.
    expect(control.state.isControlling, isFalse);
  });

  test('does not interrupt music playing on this device', () async {
    await playback.playNow([track('a')], startIndex: 0);
    await settle();

    presence.emitDevices(testScope, [playingTv()]);
    await settle();

    expect(playback.state.isPlaying, isTrue);
    expect(control.state.isControlling, isFalse);
  });

  test('asks the listener when two devices are playing', () async {
    presence.emitDevices(testScope, [
      playingTv(),
      playingTv(
        deviceId: 'device-desktop',
        sessionId: 'session-desktop',
        name: 'Desktop',
      ),
    ]);
    await settle();

    // Two speakers, no way to know which room the listener walked into.
    expect(control.state.isControlling, isFalse);
  });

  test(
    'does not re-bind to playback the listener stopped controlling',
    () async {
      presence.emitDevices(testScope, [playingTv()]);
      await settle();
      expect(control.state.isControlling, isTrue);

      await control.stop();
      await settle();

      // The television is still playing, and the roster keeps saying so.
      presence.emitDevices(testScope, [playingTv()]);
      await settle();

      expect(control.state.isControlling, isFalse);
    },
  );

  test('asks again when that device starts a new session', () async {
    presence.emitDevices(testScope, [playingTv()]);
    await settle();
    await control.stop();
    await settle();

    // The television reconnected: a new session id for the same install,
    // which is a new question rather than the one already answered.
    presence.emitDevices(testScope, [playingTv(sessionId: 'session-tv-2')]);
    await settle();

    expect(control.state.isControlling, isTrue);
    expect(control.state.device?.sessionId, 'session-tv-2');
  });

  test('asks again after that playback stops and starts', () async {
    presence.emitDevices(testScope, [playingTv()]);
    await settle();
    await control.stop();
    await settle();

    presence.emitDevices(testScope, [device()]);
    await settle();
    presence.emitDevices(testScope, [playingTv()]);
    await settle();

    expect(control.state.isControlling, isTrue);
  });
}
