import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackLimits.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceCapabilities.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteCommand.dart';
import 'package:jellyfinity/domain/connected_playback/RemotePlaybackSnapshot.dart';
import 'package:jellyfinity/domain/connected_playback/RemotePlaybackTarget.dart';
import 'package:jellyfinity/domain/connected_playback/StateRevision.dart';
import 'package:jellyfinity/domain/connected_playback/command_outcome.dart';
import 'package:jellyfinity/domain/connected_playback/remote_command_kind.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';

import '../../support/connected_playback/FakeElapsedClock.dart';
import '../../support/connected_playback/connected_playback_fixtures.dart';

/// The arbitration rules, one at a time. Everything here is pure: no
/// transport, no engine, no widget.
void main() {
  const targetSession = 'session-tv';
  late FakeElapsedClock clock;
  late RemotePlaybackTarget target;
  var nextId = 0;

  RemotePlaybackSnapshot playing({int count = 3, int index = 0}) =>
      RemotePlaybackSnapshot(
        scope: testScope,
        sessionId: targetSession,
        revision: const StateRevision(4),
        status: PlaybackStatus.playing,
        queue: entries(count),
        currentIndex: index,
      );

  RemoteCommand simple(
    RemoteCommandKind kind, {
    String? id,
    String session = targetSession,
    StateRevision? expected,
    Duration? lifetime,
  }) => SimpleRemoteCommand(
    id: id ?? 'c${nextId++}',
    scope: testScope,
    targetSessionId: session,
    kind: kind,
    expectedRevision: expected,
    lifetime: lifetime ?? ConnectedPlaybackLimits.commandLifetime,
  );

  setUp(() {
    nextId = 0;
    clock = FakeElapsedClock();
    target = RemotePlaybackTarget(initialState: playing(), clock: clock);
  });

  group('scope and addressing', () {
    test('refuses a command from another profile without applying it', () {
      final foreign = SimpleRemoteCommand(
        id: 'c-foreign',
        scope: otherProfileScope,
        targetSessionId: targetSession,
        kind: RemoteCommandKind.pause,
      );

      final acknowledgement = target.handle(foreign);

      expect(acknowledgement.outcome, CommandOutcome.outOfScope);
      expect(target.snapshot.status, PlaybackStatus.playing);
      expect(target.snapshot.revision, const StateRevision(4));
    });

    test('refuses a command addressed to a session it replaced', () {
      final acknowledgement = target.handle(
        simple(RemoteCommandKind.pause, session: 'session-tv-old'),
      );

      expect(acknowledgement.outcome, CommandOutcome.wrongTarget);
      expect(target.snapshot.status, PlaybackStatus.playing);
    });

    test(
      'does not remember another profile command id, so its own ids stay free',
      () {
        // A foreign command must not occupy the duplicate window; if it
        // did, a later legitimate command reusing that id would be
        // answered as a duplicate of something that never happened.
        target.handle(
          SimpleRemoteCommand(
            id: 'shared-id',
            scope: otherProfileScope,
            targetSessionId: targetSession,
            kind: RemoteCommandKind.pause,
          ),
        );

        final acknowledgement = target.handle(
          simple(RemoteCommandKind.pause, id: 'shared-id'),
        );

        expect(acknowledgement.outcome, CommandOutcome.applied);
      },
    );
  });

  group('duplicates', () {
    test('applies a skip once however many times it arrives', () {
      final skip = simple(RemoteCommandKind.next, id: 'c-skip');

      final first = target.handle(skip);
      final second = target.handle(skip);
      final third = target.handle(skip);

      expect(target.snapshot.currentIndex, 1);
      expect(first.outcome, CommandOutcome.applied);
      expect(second.outcome, CommandOutcome.duplicate);
      expect(third.outcome, CommandOutcome.duplicate);
    });

    test('answers a duplicate with the revision the first attempt made', () {
      final skip = simple(RemoteCommandKind.next, id: 'c-skip');
      final first = target.handle(skip);
      // Something else moves the state on in between.
      target.handle(simple(RemoteCommandKind.pause));

      final replayed = target.handle(skip);

      expect(replayed.revision, first.revision);
      expect(target.snapshot.revision, greaterThan(first.revision));
    });

    test('repeats a refusal rather than reconsidering it', () {
      final stale = SimpleRemoteCommand(
        id: 'c-stale',
        scope: testScope,
        targetSessionId: 'session-tv-old',
        kind: RemoteCommandKind.pause,
      );
      target.handle(stale);

      expect(target.handle(stale).outcome, CommandOutcome.wrongTarget);
    });

    test('forgets ids beyond its bounded window', () {
      final skip = simple(RemoteCommandKind.next, id: 'c-skip');
      target.handle(skip);
      for (var i = 0; i < ConnectedPlaybackLimits.commandHistoryLength; i++) {
        target.handle(simple(RemoteCommandKind.pause, id: 'filler-$i'));
      }

      // Not a bug being tested — a bound being documented. The window
      // covers a retry seconds later, not one after hundreds of
      // commands, and it must not grow without limit in a session that
      // runs for days.
      expect(target.handle(skip).outcome, CommandOutcome.applied);
    });
  });

  group('expiry', () {
    test('drops a command that waited too long after arriving', () {
      final pending = target.receive(
        simple(RemoteCommandKind.pause, lifetime: const Duration(seconds: 10)),
      );
      clock.advance(const Duration(seconds: 11));

      final acknowledgement = target.process(pending);

      expect(acknowledgement.outcome, CommandOutcome.expired);
      expect(target.snapshot.status, PlaybackStatus.playing);
    });

    test('applies a command processed within its lifetime', () {
      final pending = target.receive(
        simple(RemoteCommandKind.pause, lifetime: const Duration(seconds: 10)),
      );
      clock.advance(const Duration(seconds: 9));

      expect(target.process(pending).outcome, CommandOutcome.applied);
    });

    test('measures the lifetime from arrival, not from any shared clock', () {
      // The device has been up for a week; the sender has not. A
      // wall-clock expiry would be meaningless here, and this is the
      // reading that proves it is not being used.
      clock.advance(const Duration(days: 7));
      final pending = target.receive(simple(RemoteCommandKind.pause));
      clock.advance(const Duration(seconds: 1));

      expect(target.process(pending).outcome, CommandOutcome.applied);
    });
  });

  group('capability negotiation', () {
    test('refuses a command it does not advertise', () {
      target.advertise(
        const DeviceCapabilities(
          canPlay: true,
          canControl: false,
          acceptedCommands: {RemoteCommandKind.pause},
        ),
      );

      expect(
        target.handle(simple(RemoteCommandKind.next)).outcome,
        CommandOutcome.unsupported,
      );
      expect(
        target.handle(simple(RemoteCommandKind.pause)).outcome,
        CommandOutcome.applied,
      );
    });

    test('applies a narrowed advertisement to later commands only', () {
      final before = target.handle(simple(RemoteCommandKind.pause));
      target.advertise(DeviceCapabilities.none);

      expect(before.outcome, CommandOutcome.applied);
      expect(
        target.handle(simple(RemoteCommandKind.play)).outcome,
        CommandOutcome.unsupported,
      );
    });
  });

  group('revisions', () {
    test('rejects a structural command composed against an old revision', () {
      final edit = RemoveQueueEntryCommand(
        id: 'c-edit',
        scope: testScope,
        targetSessionId: targetSession,
        index: 2,
        expectedRevision: const StateRevision(3),
      );

      final acknowledgement = target.handle(edit);

      expect(acknowledgement.outcome, CommandOutcome.stale);
      // The refusal carries the truth, so the controller learns what it
      // got wrong from the same message.
      expect(acknowledgement.revision, const StateRevision(4));
      expect(target.snapshot.queue, hasLength(3));
    });

    test('serializes two controllers editing the same revision', () {
      final first = RemoveQueueEntryCommand(
        id: 'phone-edit',
        scope: testScope,
        targetSessionId: targetSession,
        index: 0,
        expectedRevision: const StateRevision(4),
      );
      final second = RemoveQueueEntryCommand(
        id: 'desktop-edit',
        scope: testScope,
        targetSessionId: targetSession,
        index: 1,
        expectedRevision: const StateRevision(4),
      );

      final firstAck = target.handle(first);
      final secondAck = target.handle(second);

      expect(firstAck.outcome, CommandOutcome.applied);
      // The second controller's "remove row 1" is not silently applied
      // to a queue where row 1 is now a different song.
      expect(secondAck.outcome, CommandOutcome.stale);
      expect(target.snapshot.queue, hasLength(2));
    });

    test('does not require a revision for a skip', () {
      // A listener pressing skip means "skip whatever is playing", and a
      // target that auto-advanced a moment ago must not refuse it.
      expect(
        target.handle(simple(RemoteCommandKind.next)).outcome,
        CommandOutcome.applied,
      );
    });

    test('bumps the revision only when something changed', () {
      final before = target.snapshot.revision;

      final snapshotRequest = target.handle(
        simple(RemoteCommandKind.requestSnapshot),
      );

      expect(snapshotRequest.outcome, CommandOutcome.applied);
      expect(target.snapshot.revision, before);
    });

    test('a local change bumps the revision and staleness follows', () {
      target.publishLocalChange(
        (current) => current.copyWith(status: PlaybackStatus.paused),
      );

      final edit = RemoveQueueEntryCommand(
        id: 'c-edit',
        scope: testScope,
        targetSessionId: targetSession,
        index: 0,
        expectedRevision: const StateRevision(4),
      );

      expect(target.snapshot.revision, const StateRevision(5));
      expect(target.handle(edit).outcome, CommandOutcome.stale);
    });
  });

  group('bounds', () {
    test('refuses a queue longer than this device accepts', () {
      target.advertise(
        DeviceCapabilities.fullPlayer().copyWith(maxQueueEntries: 2),
      );

      final acknowledgement = target.handle(
        SetQueueCommand(
          id: 'c-queue',
          scope: testScope,
          targetSessionId: targetSession,
          entries: entries(3),
          startIndex: 0,
          expectedRevision: target.snapshot.revision,
        ),
      );

      expect(acknowledgement.outcome, CommandOutcome.rejected);
      expect(target.snapshot.queue, hasLength(3));
    });

    test('refuses an append that would cross the bound', () {
      target.advertise(
        DeviceCapabilities.fullPlayer().copyWith(maxQueueEntries: 4),
      );

      final acknowledgement = target.handle(
        AppendToQueueCommand(
          id: 'c-append',
          scope: testScope,
          targetSessionId: targetSession,
          entries: entries(2),
          expectedRevision: target.snapshot.revision,
        ),
      );

      expect(acknowledgement.outcome, CommandOutcome.rejected);
    });
  });

  group('applying to state', () {
    test('rejects an edit at an index the queue does not have', () {
      final acknowledgement = target.handle(
        RemoveQueueEntryCommand(
          id: 'c-edit',
          scope: testScope,
          targetSessionId: targetSession,
          index: 9,
          expectedRevision: target.snapshot.revision,
        ),
      );

      expect(acknowledgement.outcome, CommandOutcome.rejected);
    });

    test('keeps the playing entry current across a reorder', () {
      target = RemotePlaybackTarget(
        initialState: playing(count: 4, index: 1),
        clock: clock,
      );
      final playingEntry = target.snapshot.currentEntry;

      target.handle(
        MoveQueueEntryCommand(
          id: 'c-move',
          scope: testScope,
          targetSessionId: targetSession,
          fromIndex: 3,
          toIndex: 0,
          expectedRevision: target.snapshot.revision,
        ),
      );

      expect(target.snapshot.currentEntry, playingEntry);
      expect(target.snapshot.currentIndex, 2);
    });

    test('moving the playing entry follows it', () {
      target = RemotePlaybackTarget(
        initialState: playing(count: 4, index: 1),
        clock: clock,
      );
      final playingEntry = target.snapshot.currentEntry;

      target.handle(
        MoveQueueEntryCommand(
          id: 'c-move',
          scope: testScope,
          targetSessionId: targetSession,
          fromIndex: 1,
          toIndex: 3,
          expectedRevision: target.snapshot.revision,
        ),
      );

      expect(target.snapshot.currentIndex, 3);
      expect(target.snapshot.currentEntry, playingEntry);
    });

    test('removing the last entry leaves an idle, empty queue', () {
      target = RemotePlaybackTarget(
        initialState: playing(count: 1),
        clock: clock,
      );

      target.handle(
        RemoveQueueEntryCommand(
          id: 'c-edit',
          scope: testScope,
          targetSessionId: targetSession,
          index: 0,
          expectedRevision: target.snapshot.revision,
        ),
      );

      expect(target.snapshot.queue, isEmpty);
      expect(target.snapshot.currentIndex, isNull);
      expect(target.snapshot.status, PlaybackStatus.idle);
    });

    test('stops at the end of the queue unless repeat says otherwise', () {
      target = RemotePlaybackTarget(
        initialState: playing(count: 2, index: 1),
        clock: clock,
      );

      expect(
        target.handle(simple(RemoteCommandKind.next)).outcome,
        CommandOutcome.rejected,
      );

      target.publishLocalChange(
        (current) => current.copyWith(repeatMode: RepeatMode.all),
      );

      expect(
        target.handle(simple(RemoteCommandKind.next)).outcome,
        CommandOutcome.applied,
      );
      expect(target.snapshot.currentIndex, 0);
    });

    test('an explicit skip overrides repeat-one', () {
      target.publishLocalChange(
        (current) => current.copyWith(repeatMode: RepeatMode.one),
      );

      target.handle(simple(RemoteCommandKind.next));

      expect(target.snapshot.currentIndex, 1);
    });

    test('a seek is the same state however many times it lands', () {
      target.handle(
        SeekCommand(
          id: 'c-seek-1',
          scope: testScope,
          targetSessionId: targetSession,
          position: const Duration(seconds: 30),
        ),
      );
      target.handle(
        SeekCommand(
          id: 'c-seek-2',
          scope: testScope,
          targetSessionId: targetSession,
          position: const Duration(seconds: 30),
        ),
      );

      expect(target.snapshot.position, const Duration(seconds: 30));
    });

    test('a setQueue that starts paused does not start playing', () {
      target.handle(
        SetQueueCommand(
          id: 'c-queue',
          scope: testScope,
          targetSessionId: targetSession,
          entries: entries(2),
          startIndex: 0,
          startPlaying: false,
          expectedRevision: target.snapshot.revision,
        ),
      );

      expect(target.snapshot.status, PlaybackStatus.paused);
    });
  });
}
