import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/ConnectedPlaybackTargetLink.dart';
import 'package:jellyfinity/app/connected_playback/PlaybackControlCubit.dart';
import 'package:jellyfinity/app/connected_playback/SupportedRemoteCommands.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedDevice.dart';
import 'package:jellyfinity/domain/connected_playback/device_reachability.dart';
import 'package:jellyfinity/domain/connected_playback/remote_command_kind.dart';
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

/// v0.5.6's own definition of done, restated as a test: a real
/// `ConnectedPlaybackControllerSession` chosen for a device, driven
/// end-to-end over the same deliberately unreliable network the whole arc
/// already trusts — no widget, no audio backend, no live Jellyfin server.
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
  });

  tearDown(() async {
    await control.close();
    await targetLink.stop();
    await targetPlayback.close();
    await presence.dispose();
  });

  ConnectedDevice tv({String sessionId = 'session-tv'}) => device(
    sessionId: sessionId,
    capabilities: supportedRemoteCommands,
    isPlaying: true,
  );

  group('control', () {
    test('requests and receives the target\'s real, live queue', () async {
      await control.control(tv());
      await settle();

      expect(control.state.isControlling, isTrue);
      expect(control.state.queue.entries, hasLength(3));
      expect(control.state.status, PlaybackStatus.playing);
      expect(control.state.currentEntry?.id.itemId, 'a');
    });

    test('negotiates the controller-desired commands against what the '
        'target actually advertises', () async {
      await control.control(tv());
      await settle();

      expect(
        control.state.availableCommands,
        containsAll(<RemoteCommandKind>{
          RemoteCommandKind.play,
          RemoteCommandKind.pause,
          RemoteCommandKind.playPause,
          RemoteCommandKind.previous,
          RemoteCommandKind.next,
          RemoteCommandKind.seek,
          RemoteCommandKind.setShuffle,
          RemoteCommandKind.setRepeat,
          RemoteCommandKind.jumpToQueueEntry,
        }),
      );
      // Never desired in the first place — no version's required
      // deliverables include incremental remote queue editing or a
      // settable volume (`SupportedRemoteCommands`'s own doc).
      expect(
        control.state.availableCommands,
        isNot(
          contains(
            anyOf([
              RemoteCommandKind.appendToQueue,
              RemoteCommandKind.setVolume,
            ]),
          ),
        ),
      );
      expect(
        control.state.availableCommands,
        contains(RemoteCommandKind.setQueue),
      );
    });

    test('a selected queue replaces the target and keeps control attached', () async {
      await control.control(tv());
      await settle();

      final result = control.playTracks(
        [track('b'), track('c')],
        startIndex: 1,
      );
      expect(control.state.pendingCommand, RemoteCommandKind.setQueue);
      expect(control.state.currentEntry?.id.itemId, 'c');

      await result;
      await settle();

      expect(targetPlayback.state.queue.currentEntry?.id.itemId, 'c');
      expect(control.state.currentEntry?.id.itemId, 'c');
      expect(control.state.isControlling, isTrue);
      expect(control.state.pendingCommand, isNull);
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
      await control.pause();
      await control.jumpToQueueEntry(2);
      await settle();

      expect(localPlayback.state.currentEntry?.id.itemId, 'local');
      expect(localPlayback.state.isPlaying, isTrue);
      await localPlayback.close();
    });
  });

  group('commands', () {
    test('shows pending immediately, clears once acknowledged, and the '
        'real target actually changes', () async {
      await control.control(tv());
      await settle();

      final result = control.pause();
      expect(control.state.pendingCommand, RemoteCommandKind.pause);
      await result;
      await settle();

      expect(control.state.pendingCommand, isNull);
      expect(control.state.commandStatus, PlaybackControlCommandStatus.applied);
      expect(control.state.status, PlaybackStatus.paused);
      expect(engine.playing, isFalse);
    });

    test(
      'jumpToQueueEntry moves the real queue, not just the projection',
      () async {
        await control.control(tv());
        await settle();

        await control.jumpToQueueEntry(2);
        await settle();

        expect(targetPlayback.state.queue.currentIndex, 2);
        expect(control.state.queue.currentIndex, 2);
      },
    );

    test('a well-formed but inapplicable command surfaces a commandError '
        'without forcing a resync', () async {
      await control.control(tv());
      await settle();

      await control.jumpToQueueEntry(99);
      await settle();

      expect(control.state.commandError, isNotNull);
      expect(
        control.state.commandStatus,
        PlaybackControlCommandStatus.rejected,
      );
      expect(control.state.connection, PlaybackControlConnection.synced);
    });

    test('seeking moves the displayed position immediately', () async {
      await control.control(tv());
      await settle();

      unawaited(control.seek(const Duration(seconds: 30)));
      expect(control.state.position, const Duration(seconds: 30));
      await settle();
    });
  });

  group('presence', () {
    test('the device disappearing from presence ends control', () async {
      await control.control(tv());
      await settle();

      presence.emitDevices(testScope, const []);
      await settle();

      expect(control.state.connection, PlaybackControlConnection.targetEnded);
      // Still shows the last known projection rather than blanking out —
      // "explicit about whether state is local, remote, pending, stale,
      // or unavailable", not silently empty.
      expect(control.state.isControlling, isTrue);
    });

    test('a reconnect under a new session id retargets and resyncs', () async {
      await control.control(tv());
      await settle();

      presence.emitDevices(testScope, [tv(sessionId: 'session-tv-2')]);
      await settle();

      expect(
        control.state.connection,
        PlaybackControlConnection.resynchronizing,
      );
    });

    test('an incompatible or permission-denied target ends control, not '
        'just reconnects', () async {
      await control.control(tv());
      await settle();

      presence.emitDevices(testScope, [
        tv().copyWith(reachability: DeviceReachability.incompatible),
      ]);
      await settle();

      expect(control.state.connection, PlaybackControlConnection.targetEnded);
    });
  });

  group('stop', () {
    test(
      'stops controlling without affecting the target\'s own playback',
      () async {
        await control.control(tv());
        await settle();

        await control.stop();
        await settle();

        expect(control.state.isControlling, isFalse);
        expect(targetPlayback.state.isPlaying, isTrue);
      },
    );
  });
}
