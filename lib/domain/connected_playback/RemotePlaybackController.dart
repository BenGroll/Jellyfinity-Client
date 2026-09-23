import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../playback/repeat_mode.dart';
import 'CommandAcknowledgement.dart';
import 'ConnectedDevice.dart';
import 'ConnectedPlaybackFailures.dart';
import 'PlaybackOwnership.dart';
import 'RemoteCommand.dart';
import 'RemotePlaybackSnapshot.dart';
import 'RemoteQueueEntry.dart';
import 'StateRevision.dart';
import 'device_reachability.dart';
import 'remote_command_kind.dart';

/// The controlling side of a connected session: a device driving another
/// one, holding a projection of its state.
///
/// Pure and synchronous, like [RemotePlaybackTarget], and for the same
/// reason. Between them they are the whole conversation, and neither
/// needs a socket to be exercised.
///
/// Two rules shape everything here, both from the arc's invariants.
///
/// *The projection is not a queue.* [projection] is a read-only view of
/// what another device owns. It is never merged into this device's own
/// `PlaybackQueue` or persisted through `QueueRepository` — see
/// [PlaybackOwnership.ownsLocalQueue]. The listener's own queue on this
/// device is a different listening session, and looking at the TV must
/// not cost them their place in it.
///
/// *Commands are composed against a known revision, or not at all.* Once
/// something has told this controller that its projection is wrong
/// ([needsResync]), it composes no further structural commands until a
/// fresh snapshot arrives. Composing one anyway would be guessing at
/// which row the listener meant.
class RemotePlaybackController {
  RemotePlaybackController({
    required this.localSessionId,
    required ConnectedDevice target,
    required this.commandIds,
  }) : _target = target,
       _initialTarget = target;

  /// This device's own session — the "from" of everything it sends, and
  /// the yardstick for [ownership].
  final String localSessionId;

  /// Supplies a unique id for each command composed here. Injected
  /// rather than generated internally so a contract test can produce a
  /// deterministic sequence and assert on exactly which ids a retry
  /// reuses.
  final String Function() commandIds;

  /// The device this controller was pointed at when it was created.
  /// Kept so a caller can tell a retargeted controller from a fresh one
  /// when diagnosing a reconnection.
  final ConnectedDevice _initialTarget;

  ConnectedDevice _target;
  RemotePlaybackSnapshot? _projection;
  StateRevision? _acknowledgedRevision;
  bool _needsResync = false;

  /// The device being driven.
  ConnectedDevice get target => _target;

  /// Whether [target] has been followed through a reconnection since this
  /// controller was created.
  bool get followedReconnect => _target.sessionId != _initialTarget.sessionId;

  /// The latest state this controller believes the target is in, or
  /// `null` before the first snapshot.
  ///
  /// `null` is a real state with its own UI: "connecting to Living Room"
  /// is not the same screen as "Living Room is playing nothing".
  RemotePlaybackSnapshot? get projection => _projection;

  /// Whether the projection is known to be wrong. Cleared by the next
  /// snapshot from the target's current session.
  bool get needsResync => _needsResync;

  /// The highest revision this controller has evidence of — from a
  /// snapshot, or from the acknowledgement of a command it sent.
  ///
  /// Acknowledgements run ahead of snapshots: a target answers a queue
  /// edit immediately and publishes the new state a moment later. The two
  /// are kept apart deliberately. The acknowledgement proves the
  /// *revision* moved; only the snapshot carries the new *contents*, and
  /// folding one into the other would leave the controller holding a
  /// stale queue wearing a current revision number — and then ignoring
  /// the snapshot that would have fixed it, because its revision was no
  /// longer ahead.
  StateRevision? get knownRevision {
    final acknowledged = _acknowledgedRevision;
    final projected = _projection?.revision;
    if (acknowledged == null) return projected;
    if (projected == null) return acknowledged;
    return acknowledged > projected ? acknowledged : projected;
  }

  /// Who owns playback, from this device's point of view.
  PlaybackOwnership get ownership {
    final projection = _projection;
    if (projection == null || !projection.isActivePlayer) {
      return PlaybackOwnership.unclaimed(
        scope: _target.scope,
        localSessionId: localSessionId,
      );
    }
    return PlaybackOwnership(
      scope: _target.scope,
      localSessionId: localSessionId,
      ownerSessionId: projection.sessionId,
      ownerDeviceName: _target.displayName,
    );
  }

  /// Follows the target through a reconnection.
  ///
  /// A device keeps its stable device id and gets a new session id, so
  /// the projection is discarded: revisions are per-session and the old
  /// one means nothing against the new session.
  void retarget(ConnectedDevice target) {
    final changedSession = target.sessionId != _target.sessionId;
    _target = target;
    if (changedSession) {
      _projection = null;
      _acknowledgedRevision = null;
      _needsResync = true;
    }
  }

  /// Applies an arriving snapshot, or ignores it.
  ///
  /// Returns whether [projection] changed. Three cases are dropped, and
  /// each is a real thing a shared server channel does:
  ///
  /// - a snapshot from a session this controller is not watching;
  /// - a snapshot at or below the publication sequence already held —
  ///   this is the reordering defence, and it is why the newest
  ///   *arriving* message is never simply taken. It is deliberately not
  ///   the revision: a playing target republishes its position without
  ///   changing its queue, so those updates share a revision and would
  ///   all be dropped as duplicates, freezing the controller's view;
  /// - nothing else. A snapshot from the current session later in the
  ///   sequence is always authoritative, however surprising it looks: the
  ///   target owns the truth.
  bool onSnapshot(RemotePlaybackSnapshot snapshot) {
    if (snapshot.sessionId != _target.sessionId) return false;
    if (snapshot.scope != _target.scope) return false;
    final current = _projection;
    // A peer too old to publish a sequence reports 0 every time, which
    // falls back to arrival order rather than dropping everything.
    if (current != null &&
        current.sessionId == snapshot.sessionId &&
        snapshot.sequence != 0 &&
        snapshot.sequence <= current.sequence) {
      return false;
    }
    _projection = snapshot;
    _acknowledgedRevision = null;
    _needsResync = false;
    return true;
  }

  /// Applies a target's answer to a command this controller sent.
  ///
  /// An accepted command's revision is recorded in [knownRevision] so the
  /// next edit can be composed immediately rather than after a full
  /// snapshot round trip — the difference between a remote queue screen
  /// that responds and one that stutters once per edit. The projection
  /// itself is left alone: see [knownRevision] for why the two must not
  /// be merged.
  void onAcknowledgement(CommandAcknowledgement acknowledgement) {
    if (acknowledgement.sessionId != _target.sessionId) return;
    if (acknowledgement.outcome.requiresResync) {
      _needsResync = true;
      return;
    }
    if (!acknowledgement.isAccepted) return;
    final known = knownRevision;
    if (known == null || acknowledgement.revision > known) {
      _acknowledgedRevision = acknowledgement.revision;
    }
  }

  /// Records that a command was never answered.
  ///
  /// A timeout is not a refusal: the command may well have been applied
  /// and only the answer lost. So the projection is marked wrong rather
  /// than assumed unchanged, and the caller resynchronizes instead of
  /// re-sending blind.
  void onTimeout() {
    _needsResync = true;
  }

  /// The commands that may be offered for this target right now, out of
  /// [desired].
  ///
  /// The negotiation the UI reads: a control whose command is not in the
  /// returned set is not shown, rather than shown and failing. An
  /// unreachable or incompatible target returns the empty set.
  Set<RemoteCommandKind> availableCommands(Set<RemoteCommandKind> desired) {
    if (!_target.canBeControlled) return const {};
    return _target.capabilities.negotiate(desired);
  }

  Result<RemoteCommand> play() => _simple(RemoteCommandKind.play);

  Result<RemoteCommand> pause() => _simple(RemoteCommandKind.pause);

  Result<RemoteCommand> playPause() => _simple(RemoteCommandKind.playPause);

  Result<RemoteCommand> stop() => _simple(RemoteCommandKind.stop);

  Result<RemoteCommand> next() => _simple(RemoteCommandKind.next);

  Result<RemoteCommand> previous() => _simple(RemoteCommandKind.previous);

  Result<RemoteCommand> requestSnapshot() =>
      _simple(RemoteCommandKind.requestSnapshot, needsProjection: false);

  Result<RemoteCommand> joinSyncGroup(String groupId) => _compose(
    RemoteCommandKind.joinSyncGroup,
    (id, revision) => JoinSyncGroupCommand(
      id: id,
      scope: _target.scope,
      targetSessionId: _target.sessionId,
      groupId: groupId,
    ),
    needsProjection: false,
  );

  Result<RemoteCommand> seek(Duration position) => _compose(
    RemoteCommandKind.seek,
    (id, revision) => SeekCommand(
      id: id,
      scope: _target.scope,
      targetSessionId: _target.sessionId,
      position: position,
    ),
  );

  Result<RemoteCommand> setVolume(double volume) => _compose(
    RemoteCommandKind.setVolume,
    (id, revision) => SetVolumeCommand(
      id: id,
      scope: _target.scope,
      targetSessionId: _target.sessionId,
      volume: volume,
    ),
  );

  Result<RemoteCommand> setShuffle(bool enabled) => _compose(
    RemoteCommandKind.setShuffle,
    (id, revision) => SetShuffleCommand(
      id: id,
      scope: _target.scope,
      targetSessionId: _target.sessionId,
      enabled: enabled,
    ),
  );

  Result<RemoteCommand> setRepeat(RepeatMode mode) => _compose(
    RemoteCommandKind.setRepeat,
    (id, revision) => SetRepeatCommand(
      id: id,
      scope: _target.scope,
      targetSessionId: _target.sessionId,
      repeatMode: mode,
    ),
  );

  Result<RemoteCommand> removeQueueEntry(int index) => _compose(
    RemoteCommandKind.removeQueueEntry,
    (id, revision) => RemoveQueueEntryCommand(
      id: id,
      scope: _target.scope,
      targetSessionId: _target.sessionId,
      index: index,
      expectedRevision: revision,
    ),
  );

  Result<RemoteCommand> moveQueueEntry(int fromIndex, int toIndex) => _compose(
    RemoteCommandKind.moveQueueEntry,
    (id, revision) => MoveQueueEntryCommand(
      id: id,
      scope: _target.scope,
      targetSessionId: _target.sessionId,
      fromIndex: fromIndex,
      toIndex: toIndex,
      expectedRevision: revision,
    ),
  );

  Result<RemoteCommand> jumpToQueueEntry(int index) => _compose(
    RemoteCommandKind.jumpToQueueEntry,
    (id, revision) => JumpToQueueEntryCommand(
      id: id,
      scope: _target.scope,
      targetSessionId: _target.sessionId,
      index: index,
      expectedRevision: revision,
    ),
  );

  Result<RemoteCommand> setQueue({
    required List<RemoteQueueEntry> entries,
    required int startIndex,
    required bool shuffleEnabled,
    required RepeatMode repeatMode,
    String? originName,
    Duration startPosition = Duration.zero,
    bool startPlaying = true,
  }) => _compose(
    RemoteCommandKind.setQueue,
    (id, revision) => SetQueueCommand(
      id: id,
      scope: _target.scope,
      targetSessionId: _target.sessionId,
      entries: entries,
      startIndex: startIndex,
      startPosition: startPosition,
      shuffleEnabled: shuffleEnabled,
      repeatMode: repeatMode,
      originName: originName,
      startPlaying: startPlaying,
      expectedRevision: revision,
    ),
    // Replacing the whole queue names no existing row, so it needs
    // neither a projection nor a matching revision: choosing a song for
    // another device works before this controller has read that device's
    // state, and while it is playing something else.
    needsProjection: false,
  );

  /// Asks the target to become this device's controller — see
  /// [TakeControlCommand]. Needs no projection: it is about the link, not
  /// about anything the target is playing.
  Result<RemoteCommand> takeControl(String controlSessionId) => _compose(
    RemoteCommandKind.takeControl,
    (id, revision) => TakeControlCommand(
      id: id,
      scope: _target.scope,
      targetSessionId: _target.sessionId,
      controllerOfSessionId: controlSessionId,
    ),
    needsProjection: false,
  );

  Result<RemoteCommand> appendToQueue(
    List<RemoteQueueEntry> entries, {
    bool playNext = false,
  }) => _compose(
    RemoteCommandKind.appendToQueue,
    (id, revision) => AppendToQueueCommand(
      id: id,
      scope: _target.scope,
      targetSessionId: _target.sessionId,
      entries: entries,
      expectedRevision: revision,
      playNext: playNext,
    ),
  );

  Result<RemoteCommand> _simple(
    RemoteCommandKind kind, {
    bool needsProjection = true,
  }) => _compose(
    kind,
    (id, revision) => SimpleRemoteCommand(
      id: id,
      scope: _target.scope,
      targetSessionId: _target.sessionId,
      kind: kind,
    ),
    needsProjection: needsProjection,
  );

  Result<RemoteCommand> _compose(
    RemoteCommandKind kind,
    RemoteCommand Function(String id, StateRevision? revision) build, {
    bool needsProjection = true,
  }) {
    if (!_target.canBeControlled) {
      return Err(
        _target.reachabilityFailure ?? ConnectedPlaybackFailures.notReachable(),
      );
    }
    if (!_target.capabilities.accepts(kind)) {
      return Err(
        const IncompatibleClientFailure(
          'That device does not support this control.',
        ),
      );
    }
    final projection = _projection;
    if (needsProjection && projection == null) {
      return Err(
        const UnavailableFailure('Still reading what that device is playing.'),
      );
    }
    if (kind.dependsOnCurrentQueue && (_needsResync || projection == null)) {
      return Err(
        const RecoverableFailure(
          'That device has changed. Refreshing before editing its queue.',
        ),
      );
    }
    return Ok(build(commandIds(), knownRevision));
  }
}

extension on ConnectedDevice {
  /// The failure that explains why this device cannot be driven, when the
  /// reason is specific enough to say out loud.
  Failure? get reachabilityFailure => switch (reachability) {
    DeviceReachability.incompatible =>
      ConnectedPlaybackFailures.incompatibleProtocol(),
    DeviceReachability.offline => ConnectedPlaybackFailures.offline(),
    DeviceReachability.notPermitted => const UnauthorizedFailure(
      'This account is not allowed to control that device.',
    ),
    _ => null,
  };
}
