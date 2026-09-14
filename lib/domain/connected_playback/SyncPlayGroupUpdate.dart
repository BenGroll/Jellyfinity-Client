import 'package:equatable/equatable.dart';

import '../playback/repeat_mode.dart';
import 'RemoteQueueEntry.dart';
import 'SyncPlayGroupMember.dart';

/// What the server's `GroupUpdate` messages actually tell this device
/// (v0.6.0, ADR-0045) — narrowed to the v0.6.0 requirements: who is in
/// the group, its one shared queue, and its one shared transport state.
/// Jellyfin's own SyncPlay protocol defines more `GroupUpdateType`
/// values (playback-ready negotiation, per-member buffering) than this
/// sealed set carries; an update this app does not model is decoded as
/// [UnhandledSyncPlayUpdate] rather than dropped silently, so a gap here
/// is visible in a log rather than invisible.
sealed class SyncPlayGroupUpdate extends Equatable {
  const SyncPlayGroupUpdate();
}

/// This device is now a member of [groupId] — the answer to both
/// `SyncPlayApi.createGroup` and `.joinGroup` succeeding, since Jellyfin
/// reports both the same way: a group this device is now inside, with
/// whatever it already contains.
final class SyncPlayGroupJoined extends SyncPlayGroupUpdate {
  const SyncPlayGroupJoined({
    required this.groupId,
    required this.groupName,
    required this.members,
    this.queue = const [],
    this.queuePosition = 0,
  });

  final String groupId;
  final String groupName;
  final List<SyncPlayGroupMember> members;
  final List<RemoteQueueEntry> queue;
  final int queuePosition;

  @override
  List<Object?> get props => [
    groupId,
    groupName,
    members,
    queue,
    queuePosition,
  ];
}

/// This device is no longer a member — a leave it asked for, or one the
/// server ended for it (the group's last other member left, or this
/// session was removed).
final class SyncPlayGroupLeft extends SyncPlayGroupUpdate {
  const SyncPlayGroupLeft();

  @override
  List<Object?> get props => [];
}

/// The join or create this device asked for could not succeed —
/// SyncPlay disabled on this server, or the group refused this device.
/// The v0.6.0 requirement this exists for: joining is a visible state
/// with an honest label, never a silent no-op.
final class SyncPlayJoinDenied extends SyncPlayGroupUpdate {
  const SyncPlayJoinDenied(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}

/// A member other than this device joined the group this device is
/// already in.
final class SyncPlayUserJoined extends SyncPlayGroupUpdate {
  const SyncPlayUserJoined(this.member);

  final SyncPlayGroupMember member;

  @override
  List<Object?> get props => [member];
}

/// A member other than this device left the group this device is still
/// in — distinct from [SyncPlayGroupLeft], which is about this device's
/// own membership.
final class SyncPlayUserLeft extends SyncPlayGroupUpdate {
  const SyncPlayUserLeft(this.sessionId);

  final String sessionId;

  @override
  List<Object?> get props => [sessionId];
}

/// The group's queue changed — a member set a new one, reordered it, or
/// moved to a different position in it. This is the group's *one* shared
/// queue (ADR-0045): every member reconciles against this, never a local
/// copy.
final class SyncPlayQueueUpdated extends SyncPlayGroupUpdate {
  const SyncPlayQueueUpdated({
    required this.entries,
    required this.startIndex,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.startPosition = Duration.zero,
    this.startPlaying = true,
  });

  final List<RemoteQueueEntry> entries;
  final int startIndex;
  final bool shuffleEnabled;
  final RepeatMode repeatMode;
  final Duration startPosition;
  final bool startPlaying;

  @override
  List<Object?> get props => [
    entries,
    startIndex,
    shuffleEnabled,
    repeatMode,
    startPosition,
    startPlaying,
  ];
}

/// The group's shared transport state changed — play, pause, or a seek.
/// Deliberately carries no volume: the invariant ADR-0045 states
/// explicitly is that volume never travels with a group, so this type
/// has no field it could travel in.
final class SyncPlayTransportUpdated extends SyncPlayGroupUpdate {
  const SyncPlayTransportUpdated({
    required this.isPlaying,
    required this.position,
  });

  final bool isPlaying;
  final Duration position;

  @override
  List<Object?> get props => [isPlaying, position];
}

/// A `GroupUpdate` this app does not (yet) act on — see the class doc.
/// Kept rather than discarded during decoding so a caller can log
/// exactly what arrived.
final class UnhandledSyncPlayUpdate extends SyncPlayGroupUpdate {
  const UnhandledSyncPlayUpdate(this.updateType);

  final String updateType;

  @override
  List<Object?> get props => [updateType];
}
