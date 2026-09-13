import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/ActivePlaybackRouteAdapter.dart';
import 'package:jellyfinity/app/connected_playback/ConnectedPlaybackTargetLink.dart';
import 'package:jellyfinity/app/connected_playback/PlaybackControlCubit.dart';
import 'package:jellyfinity/app/connected_playback/SupportedRemoteCommands.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedDevice.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceCapabilities.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/media/Track.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';

import '../../support/TestLogger.dart';
import '../../support/connected_playback/FakeConnectedPlaybackNetwork.dart';
import '../../support/connected_playback/FakeConnectedPlaybackTransport.dart';
import '../../support/connected_playback/FakeDevicePresenceSource.dart';
import '../../support/connected_playback/connected_playback_fixtures.dart';
import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/session_fakes.dart';
import '../../support/settings_fakes.dart';

/// `ActivePlaybackRouteAdapter` is what `JustAudioPlaybackEngine` calls
/// when a lock-screen, Windows media-session or hardware media-key press
/// arrives without going through any widget or cubit first (v0.5.7) — so
/// this drives it against a real `PlaybackControlCubit` controlling a
/// real (fake-transport) target, the same harness
/// `playback_control_cubit_test.dart` uses, rather than a mocked cubit
/// that could not tell a genuine "command actually applied" from a typo.
const Duration _testAckTimeout = Duration(milliseconds: 50);

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
  late PlaybackCubit targetPlayback;
  late FakeConnectedPlaybackTransport targetTransport;
  late FakeConnectedPlaybackTransport controllerTransport;
  late ConnectedPlaybackTargetLink targetLink;
  late FakeDevicePresenceSource presence;
  late PlaybackControlCubit control;
  late ActivePlaybackRouteAdapter route;

  ConnectedDevice tv({DeviceCapabilities? capabilities}) => device(
    sessionId: 'session-tv',
    capabilities: capabilities ?? supportedRemoteCommands,
    isPlaying: true,
  );

  setUp(() async {
    network = FakeConnectedPlaybackNetwork();
    engine = FakePlaybackEngine();
    targetPlayback = PlaybackCubit(
      engine,
      FakeQueueRepository(),
      FakeAudioSourceResolver(),
      RecordingPlaybackProgressRepository(),
      RecordingListeningHistoryRepository(),
      fakeSettingsCubit(),
    );
    targetTransport = FakeConnectedPlaybackTransport(
      network: network,
      sessionId: 'session-tv',
      scope: testScope,
      watchers: const ['session-phone'],
      acknowledgementTimeout: _testAckTimeout,
    );
    controllerTransport = FakeConnectedPlaybackTransport(
      network: network,
      sessionId: 'session-phone',
      scope: testScope,
      acknowledgementTimeout: _testAckTimeout,
    );
    targetLink = ConnectedPlaybackTargetLink(
      targetPlayback,
      targetTransport,
      fakeSessionCubit(signedIn: fakeAuthSession()),
      FakeMusicLibraryRepository()
        ..trackList = [track('a'), track('b'), track('c')],
      TestLogger(),
    );
    await targetLink.start();
    await targetPlayback.playNow([
      track('a'),
      track('b'),
      track('c'),
    ], startIndex: 0);
    await settle();

    presence = FakeDevicePresenceSource.empty();
    control = PlaybackControlCubit(
      controllerTransport,
      presence,
      fakeSessionCubit(signedIn: fakeAuthSession()),
    );
    route = ActivePlaybackRouteAdapter(control);
  });

  tearDown(() async {
    await control.close();
    await targetLink.stop();
    await targetPlayback.close();
    await presence.dispose();
  });

  test('isRemote is false until this device is controlling another one', () {
    expect(route.isRemote, isFalse);
  });

  test('isRemote becomes true once controlling starts', () async {
    await control.control(tv());
    await settle();

    expect(route.isRemote, isTrue);
  });

  test('pause() reaches the real target, not just the projection', () async {
    await control.control(tv());
    await settle();

    await route.pause();
    await settle();

    expect(targetPlayback.state.isPlaying, isFalse);
    expect(engine.playing, isFalse);
    expect(control.state.status, PlaybackStatus.paused);
  });

  test('next() advances the real target\'s queue', () async {
    await control.control(tv());
    await settle();

    await route.next();
    await settle();

    expect(targetPlayback.state.queue.currentIndex, 1);
  });

  test('seek() moves the real target\'s position', () async {
    await control.control(tv());
    await settle();

    await route.seek(const Duration(seconds: 30));
    await settle();

    expect(
      targetPlayback.state.position,
      greaterThanOrEqualTo(const Duration(seconds: 30)),
    );
  });

  test('a command the target has not advertised is silently dropped', () async {
    await control.control(
      tv(
        capabilities: const DeviceCapabilities(canPlay: true, canControl: true),
      ),
    );
    await settle();
    final indexBefore = targetPlayback.state.queue.currentIndex;

    await route.next();
    await settle();

    expect(targetPlayback.state.queue.currentIndex, indexBefore);
  });

  test('never touches this device\'s own local playback', () async {
    final localEngine = FakePlaybackEngine();
    final localPlayback = PlaybackCubit(
      localEngine,
      FakeQueueRepository(),
      FakeAudioSourceResolver(),
      RecordingPlaybackProgressRepository(),
      RecordingListeningHistoryRepository(),
      fakeSettingsCubit(),
    );
    await localPlayback.playNow([track('local')], startIndex: 0);
    await settle();

    await control.control(tv());
    await route.pause();
    await route.next();
    await settle();

    expect(localPlayback.state.currentEntry?.id.itemId, 'local');
    expect(localPlayback.state.isPlaying, isTrue);
    await localPlayback.close();
  });
}
