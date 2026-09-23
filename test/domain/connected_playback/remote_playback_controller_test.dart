import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/connected_playback/CommandAcknowledgement.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceCapabilities.dart';
import 'package:jellyfinity/domain/connected_playback/ProtocolVersion.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteCommand.dart';
import 'package:jellyfinity/domain/connected_playback/RemotePlaybackController.dart';
import 'package:jellyfinity/domain/connected_playback/RemotePlaybackSnapshot.dart';
import 'package:jellyfinity/domain/connected_playback/StateRevision.dart';
import 'package:jellyfinity/domain/connected_playback/command_outcome.dart';
import 'package:jellyfinity/domain/connected_playback/device_reachability.dart';
import 'package:jellyfinity/domain/connected_playback/remote_command_kind.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';

import '../../support/connected_playback/connected_playback_fixtures.dart';

/// The controlling side: what it accepts from the network, what it
/// refuses to compose, and what it must never touch.
void main() {
  const localSession = 'session-phone';
  late RemotePlaybackController controller;
  var nextId = 0;

  RemotePlaybackSnapshot snapshotAt(
    int revision, {
    PlaybackStatus status = PlaybackStatus.playing,
    int queueLength = 3,
    String session = 'session-tv',
    int? sequence,
  }) => RemotePlaybackSnapshot(
    scope: testScope,
    sessionId: session,
    revision: StateRevision(revision),
    // A target that changed its queue also published it, so these move
    // together unless a test is specifically about one of them.
    sequence: sequence ?? revision,
    status: status,
    queue: entries(queueLength),
    currentIndex: 0,
  );

  setUp(() {
    nextId = 0;
    controller = RemotePlaybackController(
      localSessionId: localSession,
      target: device(),
      commandIds: () => 'c${nextId++}',
    );
  });

  group('projection', () {
    test('takes the latest published state, not the newest arrival', () {
      controller.onSnapshot(snapshotAt(7));
      // A resync response overtaking a live socket update: the message
      // arrives later and describes an earlier state.
      final changed = controller.onSnapshot(snapshotAt(5));

      expect(changed, isFalse);
      expect(controller.projection?.revision, const StateRevision(7));
    });

    test('ignores a snapshot it has already seen', () {
      controller.onSnapshot(snapshotAt(7));

      expect(controller.onSnapshot(snapshotAt(7)), isFalse);
    });

    test('takes a fresh position from a target whose queue has not moved', () {
      // The common case by far: a playing device republishes about once a
      // second at the same revision. Ordering these by revision would
      // drop every one of them and freeze the controller's timeline.
      controller.onSnapshot(snapshotAt(7, sequence: 20));

      final changed = controller.onSnapshot(
        snapshotAt(
          7,
          sequence: 21,
        ).copyWith(position: const Duration(minutes: 1)),
      );

      expect(changed, isTrue);
      expect(controller.projection?.position, const Duration(minutes: 1));
    });

    test('ignores a snapshot from a session it is not watching', () {
      controller.onSnapshot(snapshotAt(7));

      final changed = controller.onSnapshot(
        snapshotAt(9, session: 'session-desktop'),
      );

      expect(changed, isFalse);
      expect(controller.projection?.sessionId, 'session-tv');
    });

    test('discards the projection when the target reconnects', () {
      controller.onSnapshot(snapshotAt(7));

      controller.retarget(device(sessionId: 'session-tv-2'));

      // Revisions are per-session; revision 7 of the old session says
      // nothing about the new one.
      expect(controller.projection, isNull);
      expect(controller.needsResync, isTrue);
      expect(controller.followedReconnect, isTrue);
    });

    test('keeps the projection when the same session is re-advertised', () {
      controller.onSnapshot(snapshotAt(7));

      controller.retarget(device(name: 'Living Room TV'));

      expect(controller.projection?.revision, const StateRevision(7));
      expect(controller.needsResync, isFalse);
    });
  });

  group('ownership', () {
    test('reports the target as owner while it is playing', () {
      controller.onSnapshot(snapshotAt(1));

      final ownership = controller.ownership;

      expect(ownership.isRemote, isTrue);
      expect(ownership.ownerDeviceName, 'Living Room');
      // The rule this whole class exists to protect: a controller must
      // never write the projection into its own persisted queue.
      expect(ownership.ownsLocalQueue, isFalse);
      expect(ownership.shouldShowRemoteControls, isTrue);
    });

    test('leaves the local queue alone only while something plays there', () {
      controller.onSnapshot(snapshotAt(1, status: PlaybackStatus.paused));

      // A paused remote device is not producing audio, so it does not
      // own playback and this device's own queue is its own business
      // again.
      expect(controller.ownership.isUnclaimed, isTrue);
      expect(controller.ownership.ownsLocalQueue, isTrue);
    });

    test('is unclaimed before the first snapshot', () {
      expect(controller.ownership.isUnclaimed, isTrue);
      expect(controller.ownership.ownsLocalQueue, isTrue);
    });
  });

  group('acknowledgements', () {
    test('advances the revision it composes against, not the projection', () {
      controller.onSnapshot(snapshotAt(7, queueLength: 3));

      controller.onAcknowledgement(
        CommandAcknowledgement.applied(
          commandId: 'c0',
          sessionId: 'session-tv',
          revision: const StateRevision(8),
        ),
      );

      // The next edit can be composed immediately rather than after a
      // full snapshot round trip...
      expect(controller.knownRevision, const StateRevision(8));
      expect(
        controller.removeQueueEntry(1).valueOrNull?.expectedRevision,
        const StateRevision(8),
      );
      // ...but the contents are still the ones it has actually seen, and
      // the snapshot carrying revision 8 is still accepted when it
      // arrives. Merging the two would leave a stale queue wearing a
      // current revision number and then ignore its own correction.
      expect(controller.projection?.revision, const StateRevision(7));
      expect(controller.onSnapshot(snapshotAt(8, queueLength: 2)), isTrue);
      expect(controller.projection?.queue, hasLength(2));
      expect(controller.needsResync, isFalse);
    });

    test('marks the projection wrong on a stale refusal', () {
      controller.onSnapshot(snapshotAt(7));

      controller.onAcknowledgement(
        CommandAcknowledgement.refused(
          commandId: 'c0',
          sessionId: 'session-tv',
          outcome: CommandOutcome.stale,
          revision: const StateRevision(9),
        ),
      );

      expect(controller.needsResync, isTrue);
    });

    test('treats a timeout as an unknown state, not an unchanged one', () {
      controller.onSnapshot(snapshotAt(7));

      controller.onTimeout();

      // The command may have been applied and only the answer lost.
      expect(controller.needsResync, isTrue);
    });

    test('ignores an acknowledgement from a session it left behind', () {
      controller.onSnapshot(snapshotAt(7));

      controller.onAcknowledgement(
        CommandAcknowledgement.refused(
          commandId: 'c0',
          sessionId: 'session-tv-old',
          outcome: CommandOutcome.stale,
          revision: const StateRevision(2),
        ),
      );

      expect(controller.needsResync, isFalse);
    });

    test('a fresh snapshot clears the resync flag', () {
      controller.onSnapshot(snapshotAt(7));
      controller.onTimeout();

      controller.onSnapshot(snapshotAt(9));

      expect(controller.needsResync, isFalse);
      expect(controller.projection?.revision, const StateRevision(9));
    });
  });

  group('composing commands', () {
    test('stamps a structural command with the revision it saw', () {
      controller.onSnapshot(snapshotAt(7));

      final command = controller.removeQueueEntry(1).valueOrNull;

      expect(command, isA<RemoveQueueEntryCommand>());
      expect(command!.expectedRevision, const StateRevision(7));
      expect(command.targetSessionId, 'session-tv');
      expect(command.id, 'c0');
    });

    test('refuses to compose a structural command while out of sync', () {
      controller.onSnapshot(snapshotAt(7));
      controller.onTimeout();

      final result = controller.removeQueueEntry(1);

      expect(result, isA<Err<RemoteCommand>>());
      expect(result.failureOrNull, isA<RecoverableFailure>());
    });

    test('still allows a transport command while out of sync', () {
      controller.onSnapshot(snapshotAt(7));
      controller.onTimeout();

      // Pressing pause must work even when the queue projection is
      // suspect: the listener means "pause", and it needs no revision.
      expect(controller.pause().isOk, isTrue);
    });

    test('composes a snapshot request before any projection exists', () {
      expect(controller.requestSnapshot().isOk, isTrue);
      expect(controller.pause().isErr, isTrue);
    });

    test('refuses a command the target does not advertise', () {
      controller = RemotePlaybackController(
        localSessionId: localSession,
        target: device(
          capabilities: const DeviceCapabilities(
            canPlay: true,
            canControl: false,
            acceptedCommands: {RemoteCommandKind.play, RemoteCommandKind.pause},
          ),
        ),
        commandIds: () => 'c${nextId++}',
      );
      controller.onSnapshot(snapshotAt(7));

      expect(controller.pause().isOk, isTrue);
      expect(
        controller.setVolume(0.5).failureOrNull,
        isA<IncompatibleClientFailure>(),
      );
    });

    test('explains an incompatible target rather than composing', () {
      controller = RemotePlaybackController(
        localSessionId: localSession,
        target: device(
          reachability: DeviceReachability.incompatible,
          protocolVersion: const ProtocolVersion(99, 0),
        ),
        commandIds: () => 'c${nextId++}',
      );

      expect(
        controller.pause().failureOrNull,
        isA<IncompatibleClientFailure>(),
      );
    });

    test('explains an offline target rather than composing', () {
      controller = RemotePlaybackController(
        localSessionId: localSession,
        target: device(reachability: DeviceReachability.offline),
        commandIds: () => 'c${nextId++}',
      );

      final failure = controller.pause().failureOrNull;

      expect(failure, isA<UnavailableFailure>());
      // Local playback is explicitly not implicated.
      expect(failure!.message, contains('unaffected'));
    });

    test('refuses a device that has presence but no command delivery', () {
      controller = RemotePlaybackController(
        localSessionId: localSession,
        target: device(reachability: DeviceReachability.presenceOnly),
        commandIds: () => 'c${nextId++}',
      );

      expect(controller.pause().isErr, isTrue);
    });
  });

  group('capability negotiation for the UI', () {
    test('offers only what the target accepts', () {
      controller = RemotePlaybackController(
        localSessionId: localSession,
        target: device(
          capabilities: const DeviceCapabilities(
            canPlay: true,
            canControl: false,
            acceptedCommands: {
              RemoteCommandKind.play,
              RemoteCommandKind.pause,
              RemoteCommandKind.next,
            },
          ),
        ),
        commandIds: () => 'c${nextId++}',
      );

      final offered = controller.availableCommands({
        RemoteCommandKind.play,
        RemoteCommandKind.pause,
        RemoteCommandKind.setVolume,
      });

      expect(offered, {RemoteCommandKind.play, RemoteCommandKind.pause});
    });

    test('offers nothing for an unreachable target', () {
      controller = RemotePlaybackController(
        localSessionId: localSession,
        target: device(reachability: DeviceReachability.presenceOnly),
        commandIds: () => 'c${nextId++}',
      );

      expect(
        controller.availableCommands(RemoteCommandKind.values.toSet()),
        isEmpty,
      );
    });
  });
}
