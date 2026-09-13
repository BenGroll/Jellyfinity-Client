import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/ConnectedPlaybackControllerSession.dart';
import 'package:jellyfinity/app/connected_playback/ConnectedPlaybackTargetLink.dart';
import 'package:jellyfinity/app/connected_playback/SupportedRemoteCommands.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteCommand.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteQueueEntry.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/media/Track.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';

import '../../support/TestLogger.dart';
import '../../support/connected_playback/FakeConnectedPlaybackNetwork.dart';
import '../../support/connected_playback/FakeConnectedPlaybackTransport.dart';
import '../../support/connected_playback/connected_playback_fixtures.dart';
import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/session_fakes.dart';
import '../../support/settings_fakes.dart';

/// v0.5.3's own definition of done: two clients, one `PlaybackCubit`
/// actually producing sound and one driving it, converging on real state
/// through the same deliberately unreliable network v0.5.1 already
/// proved the pure domain against — no widget, no audio backend, no
/// Jellyfin server.
/// Short enough that a test expecting a real timeout (no answer ever
/// arrives) does not cost 15 real seconds of `ConnectedPlaybackLimits
/// .acknowledgementTimeout`.
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
  late PlaybackCubit playback;
  late FakeConnectedPlaybackTransport targetTransport;
  late FakeConnectedPlaybackTransport controllerTransport;
  late FakeMusicLibraryRepository library;
  late ConnectedPlaybackTargetLink targetLink;
  late ConnectedPlaybackControllerSession controllerSession;

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

    library = FakeMusicLibraryRepository()
      ..trackList = [track('a'), track('b'), track('c')];

    targetLink = ConnectedPlaybackTargetLink(
      playback,
      targetTransport,
      fakeSessionCubit(signedIn: fakeAuthSession()),
      library,
      TestLogger(),
    );
    await targetLink.start();

    controllerSession = ConnectedPlaybackControllerSession(
      transport: controllerTransport,
      target: device(
        sessionId: 'session-tv',
        capabilities: supportedRemoteCommands,
      ),
      localSessionId: 'session-phone',
    );

    await playback.playNow([track('a'), track('b'), track('c')], startIndex: 0);
    await settle();
  });

  tearDown(() async {
    await targetLink.stop();
    await controllerSession.dispose();
    await playback.close();
  });

  test(
    'the queue that is actually playing arrives at the controller',
    () async {
      expect(controllerSession.projection, isNotNull);
      expect(controllerSession.projection!.queue, hasLength(3));
      expect(controllerSession.projection!.status, PlaybackStatus.playing);
      expect(controllerSession.projection!.currentIndex, 0);
    },
  );

  test('pause crosses the wire and the real target actually pauses', () async {
    final result = await controllerSession.pause();
    expect(result.isOk, isTrue);

    await settle();
    expect(engine.playing, isFalse);
    expect(playback.state.isPlaying, isFalse);
    expect(controllerSession.projection!.status, PlaybackStatus.paused);
  });

  test(
    'play is a no-op acknowledged as applied while already playing',
    () async {
      final result = await controllerSession.play();
      expect(result.isOk, isTrue);
      await settle();
      expect(engine.playing, isTrue);
    },
  );

  test('pause never resumes a device that is already paused', () async {
    await controllerSession.pause();
    await settle();
    engine.calls.clear();

    final result = await controllerSession.pause();
    expect(result.isOk, isTrue);
    await settle();

    expect(engine.calls, isNot(contains('play')));
    expect(engine.playing, isFalse);
  });

  test(
    'jumpToQueueEntry moves the real queue, not just the projection',
    () async {
      final result = await controllerSession.jumpToQueueEntry(2);
      expect(result.isOk, isTrue);
      await settle();

      expect(playback.state.queue.currentIndex, 2);
      expect(controllerSession.projection!.currentIndex, 2);
    },
  );

  test('setShuffle only toggles when it actually changes something', () async {
    expect(playback.state.queue.shuffleEnabled, isFalse);

    await controllerSession.setShuffle(true);
    await settle();
    expect(playback.state.queue.shuffleEnabled, isTrue);

    engine.calls.clear();
    final noop = await controllerSession.setShuffle(true);
    expect(noop.isOk, isTrue);
    await settle();
    expect(playback.state.queue.shuffleEnabled, isTrue);
  });

  test('setRepeat reaches the real queue', () async {
    final result = await controllerSession.setRepeat(RepeatMode.all);
    expect(result.isOk, isTrue);
    await settle();
    expect(playback.state.queue.repeatMode, RepeatMode.all);
  });

  test('setQueue (v0.5.4) resolves entries against the target library and '
      'replaces the real queue — no composer sends this yet, so it is sent '
      'directly, on the same terms a handoff commits with', () async {
    final revision = controllerSession.projection!.revision;
    final command = SetQueueCommand(
      id: 'set-queue-1',
      scope: testScope,
      targetSessionId: 'session-tv',
      entries: [
        RemoteQueueEntry(
          id: MediaId(serverId: testScope.serverId, itemId: 'c'),
          title: 'c',
        ),
        RemoteQueueEntry(
          id: MediaId(serverId: testScope.serverId, itemId: 'b'),
          title: 'b',
        ),
      ],
      startIndex: 1,
      startPlaying: false,
      expectedRevision: revision,
    );

    final acknowledged = await controllerTransport.sendCommand(command);
    await settle();

    expect(acknowledged.isOk, isTrue);
    expect(acknowledged.valueOrNull!.isAccepted, isTrue);
    expect(playback.state.queue.entries, hasLength(2));
    expect(playback.state.queue.entries[1].id.itemId, 'b');
    expect(playback.state.queue.currentIndex, 1);
    expect(engine.playing, isFalse);
  });

  test(
    'setQueue leaves the queue untouched when an entry cannot be resolved',
    () async {
      final revision = controllerSession.projection!.revision;
      final command = SetQueueCommand(
        id: 'set-queue-2',
        scope: testScope,
        targetSessionId: 'session-tv',
        entries: [
          RemoteQueueEntry(
            id: MediaId(serverId: testScope.serverId, itemId: 'nope'),
            title: 'missing',
          ),
        ],
        startIndex: 0,
        expectedRevision: revision,
      );

      final acknowledged = await controllerTransport.sendCommand(command);
      await settle();

      // Structurally accepted — RemotePlaybackTarget cannot know this
      // device has nothing for that id — but the real queue never
      // changed.
      expect(acknowledged.isOk, isTrue);
      expect(playback.state.queue.entries.map((e) => e.id.itemId), [
        'a',
        'b',
        'c',
      ]);
    },
  );

  test(
    'a command this target does not accept is refused, not silently dropped',
    () async {
      final result = await controllerSession.stop();

      expect(result.isErr, isTrue);
      expect(controllerSession.controller.needsResync, isFalse);
    },
  );

  test('duplicated delivery still costs exactly one track', () async {
    network.duplicates = 2;

    final result = await controllerSession.next();
    expect(result.isOk, isTrue);
    await settle();

    expect(playback.state.queue.currentIndex, 1);
  });

  test(
    'two controllers racing the same edit: the second is told to resync',
    () async {
      // The target only broadcasts snapshots to watchers it knows about
      // (this fake's stand-in for the server's own session query) — the
      // desktop controller needs adding, same as a real device joining
      // the presence roster the transport already tracks.
      targetTransport.watchers = [
        ...targetTransport.watchers,
        'session-desktop',
      ];
      final second = ConnectedPlaybackControllerSession(
        transport: FakeConnectedPlaybackTransport(
          network: network,
          sessionId: 'session-desktop',
          scope: testScope,
        ),
        target: device(
          sessionId: 'session-tv',
          capabilities: supportedRemoteCommands,
        ),
        localSessionId: 'session-desktop',
      );
      await controllerSession.requestSnapshot();
      await second.requestSnapshot();
      await settle();

      final firstJump = await controllerSession.jumpToQueueEntry(1);
      final secondJump = await second.jumpToQueueEntry(2);
      await settle();

      expect(firstJump.isOk, isTrue);
      expect(secondJump.isErr, isTrue);
      expect(second.controller.needsResync, isTrue);
      // The target actually moved once, following the first controller.
      expect(playback.state.queue.currentIndex, 1);

      await second.dispose();
    },
  );

  test('requestSnapshot republishes the current state on demand', () async {
    await controllerSession.pause();
    await settle();

    final before = controllerSession.projection!.revision;
    final result = await controllerSession.requestSnapshot();

    expect(result.isOk, isTrue);
    expect(controllerSession.projection!.revision, before);
    expect(controllerSession.projection!.status, PlaybackStatus.paused);
  });

  test('reconnecting to a new session is answered as wrongTarget until '
      'retargeted', () async {
    targetTransport.sessionId = 'session-tv-2';
    // Force the target link to notice the new session id.
    await playback.pause();
    await settle();

    final stale = await controllerSession.pause();
    expect(stale.isErr, isTrue);
    expect(controllerSession.controller.needsResync, isTrue);

    controllerSession.retarget(
      device(sessionId: 'session-tv-2', capabilities: supportedRemoteCommands),
    );
    await controllerSession.requestSnapshot();
    await settle();

    final resumed = await controllerSession.play();
    expect(resumed.isOk, isTrue);
  });

  test(
    'target shutdown leaves an in-flight controller with a clean failure',
    () async {
      await targetLink.stop();

      final result = await controllerSession.pause();

      expect(result.isErr, isTrue);
      expect(controllerSession.controller.needsResync, isTrue);
    },
  );

  // Command expiry itself — a command whose lifetime elapses between
  // arrival and processing — is exhaustively covered at the domain level
  // by remote_playback_target_test.dart, using RemotePlaybackTarget's own
  // receive()/process() split (FakeTargetNode.holdCommands). Reproducing
  // that gap here would mean adding an artificial delay seam to
  // ConnectedPlaybackTargetLink purely for a test to exploit — nothing in
  // v0.5.3's actual command handling introduces one, since receive() and
  // process() run back to back in _handleCommand.
}
