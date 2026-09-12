import 'dart:collection';

import '../playback/playback_status.dart';
import '../playback/repeat_mode.dart';
import 'CommandAcknowledgement.dart';
import 'ConnectedPlaybackLimits.dart';
import 'DeviceCapabilities.dart';
import 'ElapsedClock.dart';
import 'RemoteCommand.dart';
import 'RemotePlaybackSnapshot.dart';
import 'RemoteQueueEntry.dart';
import 'command_outcome.dart';
import 'remote_command_kind.dart';

/// The authoritative side of a connected session: the device making
/// sound, arbitrating what other devices ask it to do.
///
/// Pure, synchronous and free of I/O — no transport, no engine, no
/// widget. That is the point of v0.5.1: "the complete discovery, control,
/// synchronization, and handoff conversation can be exercised in pure
/// tests without a Flutter widget, audio backend, or live Jellyfin
/// server." Everything that makes connected playback *correct* — order,
/// duplicates, staleness, expiry, scope, bounds — lives here, where it
/// can be tested exhaustively in milliseconds.
///
/// What it is **not** is a second playback engine. ADR-0013 keeps
/// `PlaybackQueue` and `PlaybackEngine` application-owned, and this class
/// does not touch either: it maintains the *snapshot* — the published
/// view of state — and v0.5.3 wires the accepted commands through to the
/// real `PlaybackCubit`. Keeping those apart is what stops "what does the
/// network think is playing" and "what is actually playing" from becoming
/// two sources of truth that drift.
///
/// Arbitration happens in a fixed order, and the order is load-bearing:
///
/// 1. **Scope** — a message for another profile is refused unread.
/// 2. **Target session** — an instruction addressed to the session this
///    one replaced is not this session's to obey.
/// 3. **Duplicate** — before anything that could change an answer,
///    because a retry must get the *first* attempt's answer, even if the
///    command would be refused if it were new.
/// 4. **Expiry** — measured from arrival on this device's own monotonic
///    clock (see [ElapsedClock]).
/// 5. **Capability** — a command this device does not accept.
/// 6. **Revision** — structural commands only.
/// 7. **Application** — which can still reject on the state's own terms.
class RemotePlaybackTarget {
  RemotePlaybackTarget({
    required RemotePlaybackSnapshot initialState,
    required this.clock,
    DeviceCapabilities? capabilities,
  }) : _snapshot = initialState,
       _capabilities = capabilities ?? DeviceCapabilities.fullPlayer();

  /// This device's monotonic clock — the only thing expiry is measured
  /// against (see [ElapsedClock]).
  final ElapsedClock clock;

  RemotePlaybackSnapshot _snapshot;
  DeviceCapabilities _capabilities;

  /// Command ids already processed, oldest first, with the answer each
  /// produced. A [Queue] keeps the bound cheap: the oldest id is dropped
  /// when the window is full, which is all that is needed for duplicates
  /// that arrive from a retry or a socket replay seconds apart.
  final Queue<String> _order = Queue<String>();
  final Map<String, CommandAcknowledgement> _answered = {};

  RemotePlaybackSnapshot get snapshot => _snapshot;

  DeviceCapabilities get capabilities => _capabilities;

  /// Narrows or widens what this device accepts — audio focus lost,
  /// remote control switched off in settings. Takes effect for the next
  /// command; commands already accepted are not retracted.
  void advertise(DeviceCapabilities capabilities) {
    _capabilities = capabilities;
  }

  /// Replaces the published state because something happened *locally* —
  /// the listener pressed pause on this device, a track ended, the queue
  /// was edited here.
  ///
  /// Bumps the revision, which is what makes a controller's in-flight
  /// structural command stale. That is correct and deliberate: the
  /// listener standing at the player wins, and the controller is told to
  /// look again rather than having its edit applied to a queue that moved
  /// underneath it.
  RemotePlaybackSnapshot publishLocalChange(
    RemotePlaybackSnapshot Function(RemotePlaybackSnapshot current) change,
  ) {
    final changed = change(_snapshot);
    _snapshot = changed.copyWith(revision: _snapshot.revision.next);
    return _snapshot;
  }

  /// Stamps [command] with its arrival time on this device's clock.
  ///
  /// Separate from [process] because a real target is not always free to
  /// act the instant a message lands — it may be resolving a source or
  /// waiting on audio focus. Expiry is measured from *here*, so a command
  /// that waited too long in that gap is dropped rather than applied to a
  /// situation that has moved on.
  PendingRemoteCommand receive(RemoteCommand command) =>
      PendingRemoteCommand(command: command, arrivedAt: clock.elapsed);

  /// Arbitrates and applies a command that has already arrived.
  CommandAcknowledgement process(PendingRemoteCommand pending) {
    final command = pending.command;

    if (command.scope != _snapshot.scope) {
      // Not recorded in the duplicate window: nothing about another
      // profile's traffic should occupy this session's memory.
      return _refuse(command, CommandOutcome.outOfScope);
    }
    if (command.targetSessionId != _snapshot.sessionId) {
      return _refuse(command, CommandOutcome.wrongTarget);
    }

    final answered = _answered[command.id];
    if (answered != null) {
      return CommandAcknowledgement(
        commandId: answered.commandId,
        sessionId: answered.sessionId,
        outcome: CommandOutcome.duplicate,
        // The revision the first attempt produced, not the current one:
        // the controller asked "what did my command do", and the honest
        // answer does not change because something else happened since.
        revision: answered.revision,
        message: answered.message,
      );
    }

    if (clock.elapsed - pending.arrivedAt > command.lifetime) {
      return _record(_refuse(command, CommandOutcome.expired));
    }

    if (!_capabilities.accepts(command.kind)) {
      return _record(_refuse(command, CommandOutcome.unsupported));
    }

    if (command.kind.isStructural) {
      final expected = command.expectedRevision;
      if (expected == null || expected != _snapshot.revision) {
        return _record(_refuse(command, CommandOutcome.stale));
      }
    }

    final applied = _apply(command);
    if (applied == null) {
      return _record(_refuse(command, CommandOutcome.rejected));
    }
    if (applied != _snapshot) {
      _snapshot = applied.copyWith(revision: _snapshot.revision.next);
    }
    return _record(
      CommandAcknowledgement.applied(
        commandId: command.id,
        sessionId: _snapshot.sessionId,
        revision: _snapshot.revision,
      ),
    );
  }

  /// [receive] and [process] in one step, for a target with nothing to
  /// wait on.
  CommandAcknowledgement handle(RemoteCommand command) =>
      process(receive(command));

  /// The new state, or `null` when the command cannot apply to the state
  /// as it is. Returning the state unchanged is a legitimate answer and
  /// does *not* bump the revision — a `requestSnapshot`, or a pause on an
  /// already-paused device, has not changed anything for a controller to
  /// catch up with.
  RemotePlaybackSnapshot? _apply(RemoteCommand command) {
    final state = _snapshot;
    switch (command) {
      case SeekCommand(:final position):
        if (state.currentEntry == null) return null;
        return state.copyWith(position: position);

      case SetVolumeCommand(:final volume):
        return state.copyWith(volume: volume.clamp(0.0, 1.0));

      case SetShuffleCommand(:final enabled):
        return state.copyWith(shuffleEnabled: enabled);

      case SetRepeatCommand(:final repeatMode):
        return state.copyWith(repeatMode: repeatMode);

      case SetQueueCommand(
        :final entries,
        :final startIndex,
        :final startPosition,
        :final shuffleEnabled,
        :final repeatMode,
        :final originName,
        :final startPlaying,
      ):
        if (entries.length > _capabilities.maxQueueEntries) return null;
        if (entries.isEmpty || startIndex < 0 || startIndex >= entries.length) {
          return null;
        }
        return state.copyWith(
          queue: List<RemoteQueueEntry>.unmodifiable(entries),
          currentIndex: startIndex,
          position: startPosition,
          shuffleEnabled: shuffleEnabled,
          repeatMode: repeatMode,
          originName: originName,
          clearOrigin: originName == null,
          status: startPlaying ? PlaybackStatus.playing : PlaybackStatus.paused,
        );

      case AppendToQueueCommand(:final entries):
        if (entries.isEmpty) return null;
        final appended = [...state.queue, ...entries];
        if (appended.length > _capabilities.maxQueueEntries) return null;
        return state.copyWith(queue: appended);

      case RemoveQueueEntryCommand(:final index):
        return _removeAt(state, index);

      case MoveQueueEntryCommand(:final fromIndex, :final toIndex):
        return _move(state, fromIndex, toIndex);

      case JumpToQueueEntryCommand(:final index):
        if (index < 0 || index >= state.queue.length) return null;
        return state.copyWith(
          currentIndex: index,
          position: Duration.zero,
          status: PlaybackStatus.playing,
        );

      case SimpleRemoteCommand(:final kind):
        return _applySimple(state, kind);
    }
  }

  RemotePlaybackSnapshot? _applySimple(
    RemotePlaybackSnapshot state,
    RemoteCommandKind kind,
  ) {
    switch (kind) {
      case RemoteCommandKind.requestSnapshot:
        // No state change, and deliberately no revision bump: the answer
        // is the snapshot itself, republished by the caller.
        return state;

      case RemoteCommandKind.play:
        if (state.currentEntry == null) return null;
        return state.copyWith(status: PlaybackStatus.playing);

      case RemoteCommandKind.pause:
        if (state.currentEntry == null) return null;
        return state.copyWith(status: PlaybackStatus.paused);

      case RemoteCommandKind.playPause:
        if (state.currentEntry == null) return null;
        return state.copyWith(
          status: state.status.isActive
              ? PlaybackStatus.paused
              : PlaybackStatus.playing,
        );

      case RemoteCommandKind.stop:
        return state.copyWith(
          status: PlaybackStatus.idle,
          position: Duration.zero,
        );

      case RemoteCommandKind.next:
        return _step(state, forward: true);

      case RemoteCommandKind.previous:
        return _step(state, forward: false);

      case RemoteCommandKind.seek:
      case RemoteCommandKind.setVolume:
      case RemoteCommandKind.setShuffle:
      case RemoteCommandKind.setRepeat:
      case RemoteCommandKind.setQueue:
      case RemoteCommandKind.appendToQueue:
      case RemoteCommandKind.removeQueueEntry:
      case RemoteCommandKind.moveQueueEntry:
      case RemoteCommandKind.jumpToQueueEntry:
        // Carried by a payload-bearing subclass; a bare
        // SimpleRemoteCommand of one of these kinds is malformed.
        return null;
    }
  }

  /// Skip, honouring repeat.
  ///
  /// The snapshot's queue is already in play order (shuffle is the
  /// owner's business — see [RemotePlaybackSnapshot.queue]), so stepping
  /// is index arithmetic rather than a second implementation of
  /// `PlaybackQueue`'s play-order rules.
  RemotePlaybackSnapshot? _step(
    RemotePlaybackSnapshot state, {
    required bool forward,
  }) {
    final index = state.currentIndex;
    if (index == null || state.queue.isEmpty) return null;

    if (state.repeatMode == RepeatMode.one) {
      // An explicit skip is the listener overriding repeat-one, not
      // asking to hear the same track again.
      final next = forward ? index + 1 : index - 1;
      if (next < 0 || next >= state.queue.length) {
        return state.copyWith(position: Duration.zero);
      }
      return state.copyWith(currentIndex: next, position: Duration.zero);
    }

    var next = forward ? index + 1 : index - 1;
    if (next >= state.queue.length) {
      if (state.repeatMode != RepeatMode.all) return null;
      next = 0;
    } else if (next < 0) {
      if (state.repeatMode != RepeatMode.all) return null;
      next = state.queue.length - 1;
    }
    return state.copyWith(
      currentIndex: next,
      position: Duration.zero,
      status: PlaybackStatus.playing,
    );
  }

  RemotePlaybackSnapshot? _removeAt(RemotePlaybackSnapshot state, int index) {
    if (index < 0 || index >= state.queue.length) return null;
    final queue = [...state.queue]..removeAt(index);
    final current = state.currentIndex;
    if (queue.isEmpty) {
      return state.copyWith(
        queue: queue,
        clearCurrentIndex: true,
        status: PlaybackStatus.idle,
        position: Duration.zero,
      );
    }
    if (current == null) return state.copyWith(queue: queue);
    if (index < current) {
      return state.copyWith(queue: queue, currentIndex: current - 1);
    }
    if (index == current) {
      // Removing what is playing moves to whatever slid into its slot,
      // clamped at the end — the same behaviour the local queue screen
      // already has, so the two devices do not disagree about it.
      final next = current >= queue.length ? queue.length - 1 : current;
      return state.copyWith(
        queue: queue,
        currentIndex: next,
        position: Duration.zero,
      );
    }
    return state.copyWith(queue: queue);
  }

  RemotePlaybackSnapshot? _move(
    RemotePlaybackSnapshot state,
    int fromIndex,
    int toIndex,
  ) {
    final length = state.queue.length;
    if (fromIndex < 0 || fromIndex >= length) return null;
    if (toIndex < 0 || toIndex >= length) return null;
    if (fromIndex == toIndex) return state;

    final queue = [...state.queue];
    final moved = queue.removeAt(fromIndex);
    queue.insert(toIndex, moved);

    var current = state.currentIndex;
    if (current != null) {
      // Follow the entry that is playing rather than the slot it was in:
      // a reorder must never silently change which song is current.
      if (current == fromIndex) {
        current = toIndex;
      } else if (fromIndex < current && toIndex >= current) {
        current -= 1;
      } else if (fromIndex > current && toIndex <= current) {
        current += 1;
      }
    }
    return state.copyWith(queue: queue, currentIndex: current);
  }

  CommandAcknowledgement _refuse(
    RemoteCommand command,
    CommandOutcome outcome,
  ) => CommandAcknowledgement.refused(
    commandId: command.id,
    sessionId: _snapshot.sessionId,
    outcome: outcome,
    revision: _snapshot.revision,
  );

  CommandAcknowledgement _record(CommandAcknowledgement acknowledgement) {
    _answered[acknowledgement.commandId] = acknowledgement;
    _order.addLast(acknowledgement.commandId);
    while (_order.length > ConnectedPlaybackLimits.commandHistoryLength) {
      _answered.remove(_order.removeFirst());
    }
    return acknowledgement;
  }
}

/// A command that has reached a target but has not been acted on yet,
/// carrying the arrival reading of the target's own monotonic clock.
class PendingRemoteCommand {
  const PendingRemoteCommand({required this.command, required this.arrivedAt});

  final RemoteCommand command;

  /// [ElapsedClock.elapsed] at the moment this arrived. Expiry is
  /// measured from here and nowhere else.
  final Duration arrivedAt;
}
