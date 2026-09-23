import 'package:equatable/equatable.dart';

import '../playback/repeat_mode.dart';
import 'ConnectedPlaybackLimits.dart';
import 'ConnectedPlaybackScope.dart';
import 'RemoteQueueEntry.dart';
import 'StateRevision.dart';
import 'remote_command_kind.dart';

/// One instruction from a controller to a target.
///
/// Every command carries the four things the arc's invariant requires —
/// "a unique id, target session, expected state revision, and a bounded
/// lifetime" — and they each answer a specific failure:
///
/// - [id] makes duplicates harmless. A retry, or a socket replaying a
///   message after a reconnect, is recognized and answered with the
///   result of the first attempt rather than applied twice. Without it a
///   retried `next` costs the listener a song.
/// - [targetSessionId] makes a stale address visible. Sessions are
///   ephemeral; a command composed just before the target reconnected
///   names a session that no longer exists, and the new session refuses
///   it instead of obeying an instruction meant for its predecessor.
/// - [expectedRevision] serializes competing controllers — see
///   [StateRevision]. Required for a structural command, meaningless for
///   a transport one, which is why it is nullable. See
///   [RemoteCommandKind.isStructural] for why "skip" is not structural
///   even though it moves the current entry.
/// - [lifetime] bounds how long the instruction stays meaningful. A pause
///   delivered thirty seconds late is not a pause the listener still
///   wants. It is a *duration*, measured by the receiver against its own
///   monotonic clock — see `ElapsedClock`.
///
/// The subclasses below are pure data. They do not know how to apply
/// themselves: `RemotePlaybackTarget` does that, because applying a
/// command means arbitrating it first, and a command that could apply
/// itself would be a command that could skip the arbitration.
sealed class RemoteCommand extends Equatable {
  const RemoteCommand({
    required this.id,
    required this.scope,
    required this.targetSessionId,
    this.expectedRevision,
    this.lifetime = ConnectedPlaybackLimits.commandLifetime,
  });

  /// Unique per command instance — not per command *kind*, and not
  /// reused by a retry of the same instruction. A retry of a lost command
  /// keeps the id it was first sent with; that is what makes it a retry
  /// rather than a second instruction.
  final String id;

  final ConnectedPlaybackScope scope;

  /// The ephemeral Jellyfin session this is addressed to — never a device
  /// id (see [ConnectedDevice]).
  final String targetSessionId;

  /// The revision this command was composed against, or `null` for a
  /// command that does not depend on one.
  final StateRevision? expectedRevision;

  /// How long this stays actionable once it reaches its target.
  final Duration lifetime;

  RemoteCommandKind get kind;

  /// The command-specific fields, for the wire envelope. The common
  /// fields above are written by `ConnectedPlaybackEnvelope`; this is
  /// only what makes this command different from the others.
  Map<String, Object?> get payload => const {};

  @override
  List<Object?> get props => [
    id,
    scope,
    targetSessionId,
    expectedRevision,
    lifetime,
    kind,
    payload,
  ];
}

/// A command with no arguments — play, pause, next, and the rest.
///
/// One class rather than eight empty ones: the [kind] *is* the whole
/// instruction, and eight identical declarations would be eight places to
/// forget a field.
final class SimpleRemoteCommand extends RemoteCommand {
  const SimpleRemoteCommand({
    required super.id,
    required super.scope,
    required super.targetSessionId,
    required this.kind,
    super.expectedRevision,
    super.lifetime,
  });

  @override
  final RemoteCommandKind kind;
}

/// Seek the current entry to an absolute [position].
///
/// Absolute rather than relative on purpose: a relative "forward 10s"
/// that arrives twice moves twenty, and the arc requires duplicates to be
/// processed once. An absolute seek applied twice is the same place. The
/// ten-second-skip remote buttons (ADR-0036) compose an absolute target
/// from the snapshot they are looking at.
final class SeekCommand extends RemoteCommand {
  const SeekCommand({
    required super.id,
    required super.scope,
    required super.targetSessionId,
    required this.position,
    super.expectedRevision,
    super.lifetime,
  });

  final Duration position;

  @override
  RemoteCommandKind get kind => RemoteCommandKind.seek;

  @override
  Map<String, Object?> get payload => {'positionMs': position.inMilliseconds};
}

/// Set the target's output volume, `0.0`-`1.0`.
final class SetVolumeCommand extends RemoteCommand {
  const SetVolumeCommand({
    required super.id,
    required super.scope,
    required super.targetSessionId,
    required this.volume,
    super.expectedRevision,
    super.lifetime,
  });

  final double volume;

  @override
  RemoteCommandKind get kind => RemoteCommandKind.setVolume;

  @override
  Map<String, Object?> get payload => {'volume': volume};
}

final class SetShuffleCommand extends RemoteCommand {
  const SetShuffleCommand({
    required super.id,
    required super.scope,
    required super.targetSessionId,
    required this.enabled,
    super.expectedRevision,
    super.lifetime,
  });

  final bool enabled;

  @override
  RemoteCommandKind get kind => RemoteCommandKind.setShuffle;

  @override
  Map<String, Object?> get payload => {'enabled': enabled};
}

final class SetRepeatCommand extends RemoteCommand {
  const SetRepeatCommand({
    required super.id,
    required super.scope,
    required super.targetSessionId,
    required this.repeatMode,
    super.expectedRevision,
    super.lifetime,
  });

  final RepeatMode repeatMode;

  @override
  RemoteCommandKind get kind => RemoteCommandKind.setRepeat;

  @override
  Map<String, Object?> get payload => {'repeatMode': repeatMode.name};
}

/// A directed request for the receiving device to join a SyncPlay group.
/// It has no expected revision because membership belongs to SyncPlay.
final class JoinSyncGroupCommand extends RemoteCommand {
  const JoinSyncGroupCommand({
    required super.id,
    required super.scope,
    required super.targetSessionId,
    required this.groupId,
    super.lifetime,
  });

  final String groupId;

  @override
  RemoteCommandKind get kind => RemoteCommandKind.joinSyncGroup;

  @override
  Map<String, Object?> get payload => {'groupId': groupId};
}

/// Asks the receiver to start controlling the session named here — the
/// sender's own, in every use this build has.
///
/// The session is carried explicitly rather than read from the envelope's
/// sender so the instruction is complete on its own: a device is told
/// which session to drive, not left to infer it from how the message
/// happened to arrive.
final class TakeControlCommand extends RemoteCommand {
  const TakeControlCommand({
    required super.id,
    required super.scope,
    required super.targetSessionId,
    required this.controllerOfSessionId,
    super.lifetime,
  });

  /// The session the receiver should begin controlling.
  final String controllerOfSessionId;

  @override
  RemoteCommandKind get kind => RemoteCommandKind.takeControl;

  @override
  Map<String, Object?> get payload => {
    'controlSessionId': controllerOfSessionId,
  };
}

/// Replace the target's whole queue and start at [startIndex].
///
/// The one structural command that is naturally idempotent: sending the
/// same queue twice leaves the same queue. It is also the command a
/// handoff commits with, which is why a target that cannot accept it
/// cannot receive a transfer ([DeviceCapabilities.canReceiveTransfer]).
final class SetQueueCommand extends RemoteCommand {
  const SetQueueCommand({
    required super.id,
    required super.scope,
    required super.targetSessionId,
    required this.entries,
    required this.startIndex,
    this.startPosition = Duration.zero,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.originName,
    this.startPlaying = true,
    super.expectedRevision,
    super.lifetime,
  });

  final List<RemoteQueueEntry> entries;
  final int startIndex;

  /// Where in [startIndex]'s entry to resume — the difference between
  /// transferring playback and restarting the song.
  final Duration startPosition;

  final bool shuffleEnabled;
  final RepeatMode repeatMode;
  final String? originName;

  /// Whether the target should begin playing once it has resolved the
  /// queue. False leaves it primed and paused, the same shape a cold-start
  /// restore uses (ADR-0013) — no surprise audio.
  final bool startPlaying;

  @override
  RemoteCommandKind get kind => RemoteCommandKind.setQueue;

  @override
  Map<String, Object?> get payload => {
    'entries': [for (final entry in entries) entry.toJson()],
    'startIndex': startIndex,
    'startPositionMs': startPosition.inMilliseconds,
    'shuffleEnabled': shuffleEnabled,
    'repeatMode': repeatMode.name,
    'originName': originName,
    'startPlaying': startPlaying,
  };
}

/// Append [entries] to the end of the target's queue.
final class AppendToQueueCommand extends RemoteCommand {
  const AppendToQueueCommand({
    required super.id,
    required super.scope,
    required super.targetSessionId,
    required this.entries,
    required super.expectedRevision,
    this.playNext = false,
    super.lifetime,
  });

  final List<RemoteQueueEntry> entries;

  /// Whether these belong immediately after whatever is playing rather
  /// than at the end — "play next" and "add to queue" are the same edit
  /// to the same queue, differing only in where it lands.
  final bool playNext;

  @override
  RemoteCommandKind get kind => RemoteCommandKind.appendToQueue;

  @override
  Map<String, Object?> get payload => {
    'entries': [for (final entry in entries) entry.toJson()],
    if (playNext) 'playNext': true,
  };
}

/// Remove the entry at [index].
///
/// By index, against [RemoteCommand.expectedRevision] — not by item id.
/// A queue can hold the same track twice, so an id does not name a row;
/// and an index without a revision names whatever has since slid into
/// that slot. The pair is what makes "remove the fourth row I am looking
/// at" mean that and nothing else.
final class RemoveQueueEntryCommand extends RemoteCommand {
  const RemoveQueueEntryCommand({
    required super.id,
    required super.scope,
    required super.targetSessionId,
    required this.index,
    required super.expectedRevision,
    super.lifetime,
  });

  final int index;

  @override
  RemoteCommandKind get kind => RemoteCommandKind.removeQueueEntry;

  @override
  Map<String, Object?> get payload => {'index': index};
}

/// Move the entry at [fromIndex] to [toIndex].
final class MoveQueueEntryCommand extends RemoteCommand {
  const MoveQueueEntryCommand({
    required super.id,
    required super.scope,
    required super.targetSessionId,
    required this.fromIndex,
    required this.toIndex,
    required super.expectedRevision,
    super.lifetime,
  });

  final int fromIndex;
  final int toIndex;

  @override
  RemoteCommandKind get kind => RemoteCommandKind.moveQueueEntry;

  @override
  Map<String, Object?> get payload => {
    'fromIndex': fromIndex,
    'toIndex': toIndex,
  };
}

/// Make the entry at [index] the current one.
final class JumpToQueueEntryCommand extends RemoteCommand {
  const JumpToQueueEntryCommand({
    required super.id,
    required super.scope,
    required super.targetSessionId,
    required this.index,
    required super.expectedRevision,
    super.lifetime,
  });

  final int index;

  @override
  RemoteCommandKind get kind => RemoteCommandKind.jumpToQueueEntry;

  @override
  Map<String, Object?> get payload => {'index': index};
}

/// Encoding and decoding for the [RemoteCommand] family.
///
/// Kept beside the family rather than in a general codec so that adding a
/// command means touching one file: the subclass, its [RemoteCommand.kind],
/// and the one branch below. A command that is added without a decode
/// branch fails loudly in the family's own round-trip test rather than
/// quietly becoming `CommandOutcome.unsupported` on every peer.
extension RemoteCommandCodec on RemoteCommand {
  /// The full envelope payload: the common fields plus [payload].
  Map<String, Object?> toPayload() => {
    'commandId': id,
    'target': targetSessionId,
    'command': kind.wireName,
    'lifetimeMs': lifetime.inMilliseconds,
    if (expectedRevision != null) 'expectedRevision': expectedRevision!.value,
    ...payload,
  };
}

/// The outcome of reading a command off the wire.
///
/// Three cases rather than a nullable command, because an older build
/// receiving a newer one's command has to answer
/// [CommandOutcome.unsupported] — and it can only do that if it recovered
/// the command id and target from a payload whose *command name* it did
/// not recognize. Collapsing "unreadable" and "unknown command" into
/// `null` would turn every new command into silence at the far end.
sealed class RemoteCommandDecoding {
  const RemoteCommandDecoding();
}

final class DecodedRemoteCommand extends RemoteCommandDecoding {
  const DecodedRemoteCommand(this.command);

  final RemoteCommand command;
}

/// A well-formed command this build does not implement.
final class UnsupportedRemoteCommand extends RemoteCommandDecoding {
  const UnsupportedRemoteCommand({
    required this.commandId,
    required this.targetSessionId,
    required this.commandName,
  });

  final String commandId;
  final String targetSessionId;

  /// The unrecognized name, for the log line. Never shown to the
  /// listener: "jellyfinity does not support `setCrossfade`" is a
  /// developer's sentence, not a listener's.
  final String commandName;
}

/// A payload missing something every command needs. There is nothing to
/// answer, because there is no id to answer about.
final class UnreadableRemoteCommand extends RemoteCommandDecoding {
  const UnreadableRemoteCommand(this.detail);

  final String detail;
}

/// Reads a command from an envelope payload. Never throws.
RemoteCommandDecoding decodeRemoteCommand(
  Map<String, Object?> payload, {
  required ConnectedPlaybackScope scope,
}) {
  final commandId = _string(payload['commandId']);
  final target = _string(payload['target']);
  final commandName = _string(payload['command']);
  if (commandId == null || target == null || commandName == null) {
    return const UnreadableRemoteCommand(
      'missing commandId, target or command name',
    );
  }

  final kind = RemoteCommandKind.tryParse(commandName);
  if (kind == null) {
    return UnsupportedRemoteCommand(
      commandId: commandId,
      targetSessionId: target,
      commandName: commandName,
    );
  }

  final lifetimeMs = payload['lifetimeMs'];
  final lifetime = lifetimeMs is int && lifetimeMs > 0
      ? Duration(milliseconds: lifetimeMs)
      : ConnectedPlaybackLimits.commandLifetime;
  final expected = payload.containsKey('expectedRevision')
      ? StateRevision.tryParse(payload['expectedRevision'])
      : null;

  RemoteCommand simple() => SimpleRemoteCommand(
    id: commandId,
    scope: scope,
    targetSessionId: target,
    kind: kind,
    expectedRevision: expected,
    lifetime: lifetime,
  );

  switch (kind) {
    case RemoteCommandKind.seek:
      final positionMs = payload['positionMs'];
      if (positionMs is! int || positionMs < 0) {
        return const UnreadableRemoteCommand('seek without a position');
      }
      return DecodedRemoteCommand(
        SeekCommand(
          id: commandId,
          scope: scope,
          targetSessionId: target,
          position: Duration(milliseconds: positionMs),
          expectedRevision: expected,
          lifetime: lifetime,
        ),
      );
    case RemoteCommandKind.setVolume:
      final volume = payload['volume'];
      if (volume is! num) {
        return const UnreadableRemoteCommand('setVolume without a volume');
      }
      return DecodedRemoteCommand(
        SetVolumeCommand(
          id: commandId,
          scope: scope,
          targetSessionId: target,
          volume: volume.toDouble().clamp(0.0, 1.0),
          expectedRevision: expected,
          lifetime: lifetime,
        ),
      );
    case RemoteCommandKind.setShuffle:
      final enabled = payload['enabled'];
      if (enabled is! bool) {
        return const UnreadableRemoteCommand('setShuffle without a value');
      }
      return DecodedRemoteCommand(
        SetShuffleCommand(
          id: commandId,
          scope: scope,
          targetSessionId: target,
          enabled: enabled,
          expectedRevision: expected,
          lifetime: lifetime,
        ),
      );
    case RemoteCommandKind.setRepeat:
      final mode = _repeatMode(payload['repeatMode']);
      if (mode == null) {
        return const UnreadableRemoteCommand('setRepeat without a mode');
      }
      return DecodedRemoteCommand(
        SetRepeatCommand(
          id: commandId,
          scope: scope,
          targetSessionId: target,
          repeatMode: mode,
          expectedRevision: expected,
          lifetime: lifetime,
        ),
      );
    case RemoteCommandKind.joinSyncGroup:
      final groupId = _string(payload['groupId']);
      if (groupId == null) {
        return const UnreadableRemoteCommand('joinSyncGroup without a group');
      }
      return DecodedRemoteCommand(
        JoinSyncGroupCommand(
          id: commandId,
          scope: scope,
          targetSessionId: target,
          groupId: groupId,
          lifetime: lifetime,
        ),
      );
    case RemoteCommandKind.takeControl:
      final controlSessionId = _string(payload['controlSessionId']);
      if (controlSessionId == null) {
        return const UnreadableRemoteCommand(
          'takeControl without a session to control',
        );
      }
      return DecodedRemoteCommand(
        TakeControlCommand(
          id: commandId,
          scope: scope,
          targetSessionId: target,
          controllerOfSessionId: controlSessionId,
          lifetime: lifetime,
        ),
      );
    case RemoteCommandKind.setQueue:
      final entries = _entries(payload['entries'], scope.serverId);
      final startIndex = payload['startIndex'];
      if (entries == null || startIndex is! int) {
        return const UnreadableRemoteCommand('setQueue without a usable queue');
      }
      final startPositionMs = payload['startPositionMs'];
      return DecodedRemoteCommand(
        SetQueueCommand(
          id: commandId,
          scope: scope,
          targetSessionId: target,
          entries: entries,
          startIndex: startIndex,
          startPosition: startPositionMs is int && startPositionMs > 0
              ? Duration(milliseconds: startPositionMs)
              : Duration.zero,
          shuffleEnabled: payload['shuffleEnabled'] == true,
          repeatMode: _repeatMode(payload['repeatMode']) ?? RepeatMode.off,
          originName: _string(payload['originName']),
          startPlaying: payload['startPlaying'] != false,
          expectedRevision: expected,
          lifetime: lifetime,
        ),
      );
    case RemoteCommandKind.appendToQueue:
      final entries = _entries(payload['entries'], scope.serverId);
      if (entries == null || expected == null) {
        return const UnreadableRemoteCommand(
          'appendToQueue without entries or an expected revision',
        );
      }
      return DecodedRemoteCommand(
        AppendToQueueCommand(
          id: commandId,
          scope: scope,
          targetSessionId: target,
          entries: entries,
          expectedRevision: expected,
          playNext: payload['playNext'] == true,
          lifetime: lifetime,
        ),
      );
    case RemoteCommandKind.removeQueueEntry:
      final index = payload['index'];
      if (index is! int || expected == null) {
        return const UnreadableRemoteCommand(
          'removeQueueEntry without an index or an expected revision',
        );
      }
      return DecodedRemoteCommand(
        RemoveQueueEntryCommand(
          id: commandId,
          scope: scope,
          targetSessionId: target,
          index: index,
          expectedRevision: expected,
          lifetime: lifetime,
        ),
      );
    case RemoteCommandKind.jumpToQueueEntry:
      final index = payload['index'];
      if (index is! int || expected == null) {
        return const UnreadableRemoteCommand(
          'jumpToQueueEntry without an index or an expected revision',
        );
      }
      return DecodedRemoteCommand(
        JumpToQueueEntryCommand(
          id: commandId,
          scope: scope,
          targetSessionId: target,
          index: index,
          expectedRevision: expected,
          lifetime: lifetime,
        ),
      );
    case RemoteCommandKind.moveQueueEntry:
      final from = payload['fromIndex'];
      final to = payload['toIndex'];
      if (from is! int || to is! int || expected == null) {
        return const UnreadableRemoteCommand(
          'moveQueueEntry without both indices or an expected revision',
        );
      }
      return DecodedRemoteCommand(
        MoveQueueEntryCommand(
          id: commandId,
          scope: scope,
          targetSessionId: target,
          fromIndex: from,
          toIndex: to,
          expectedRevision: expected,
          lifetime: lifetime,
        ),
      );
    case RemoteCommandKind.play:
    case RemoteCommandKind.pause:
    case RemoteCommandKind.playPause:
    case RemoteCommandKind.stop:
    case RemoteCommandKind.next:
    case RemoteCommandKind.previous:
    case RemoteCommandKind.requestSnapshot:
      return DecodedRemoteCommand(simple());
  }
}

List<RemoteQueueEntry>? _entries(Object? value, String localServerId) {
  if (value is! List) return null;
  final entries = <RemoteQueueEntry>[];
  for (final raw in value) {
    final entry = RemoteQueueEntry.tryDecode(raw);
    // An entry that cannot be identified fails the whole queue rather
    // than being skipped: the arc forbids silently removing or
    // reordering entries, and a queue one track shorter than the one the
    // listener transferred is exactly that.
    if (entry == null) return null;
    entries.add(entry.forLocalServer(localServerId));
  }
  return entries;
}

RepeatMode? _repeatMode(Object? value) {
  if (value is! String) return null;
  for (final mode in RepeatMode.values) {
    if (mode.name == value) return mode;
  }
  return null;
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
