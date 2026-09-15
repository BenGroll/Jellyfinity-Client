import 'package:equatable/equatable.dart';

import '../playback/playback_status.dart';
import '../playback/repeat_mode.dart';
import 'ConnectedPlaybackScope.dart';
import 'RemoteQueueEntry.dart';
import 'StateRevision.dart';

/// Everything a controller is allowed to know about what a target is
/// playing, at one [revision].
///
/// The arc's ownership invariant, restated as a type: only the device
/// producing audio owns the authoritative live queue, and *this* is what
/// everybody else gets — a revisioned projection. A controller renders
/// it, composes commands against it, and must never merge it into its own
/// persisted `PlaybackQueue` (ADR-0013). That queue is a different
/// listening session; overwriting it because the listener glanced at
/// another device's playback would lose their place for no reason they
/// asked for.
///
/// The snapshot reuses [PlaybackStatus] and [RepeatMode] rather than
/// defining remote twins of them. They describe the same facts, they
/// already avoid leaking any engine's vocabulary, and a second set of
/// enums would only create a mapping to get wrong.
class RemotePlaybackSnapshot extends Equatable {
  const RemotePlaybackSnapshot({
    required this.scope,
    required this.sessionId,
    required this.revision,
    required this.status,
    this.queue = const [],
    this.currentIndex,
    this.position = Duration.zero,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.volume,
    this.originName,
    this.syncGroupId,
  });

  /// What a target that has nothing loaded reports. A controller showing
  /// this knows the device is reachable and silent, which is different
  /// from knowing nothing about it.
  factory RemotePlaybackSnapshot.idle({
    required ConnectedPlaybackScope scope,
    required String sessionId,
    StateRevision revision = StateRevision.initial,
  }) => RemotePlaybackSnapshot(
    scope: scope,
    sessionId: sessionId,
    revision: revision,
    status: PlaybackStatus.idle,
  );

  final ConnectedPlaybackScope scope;

  /// The session that owns this state. A snapshot is only ever compared
  /// with another snapshot from the same session — [revision] counters
  /// are per-session and mean nothing across one.
  final String sessionId;

  final StateRevision revision;
  final PlaybackStatus status;

  /// The target's queue in its own order, already shuffled if shuffle is
  /// on — a controller draws what will play, it does not recompute play
  /// order. `PlaybackQueue`'s separation of entry order from shuffle
  /// order is an ownership detail of the device that owns the queue.
  final List<RemoteQueueEntry> queue;

  /// Index into [queue] of the current entry, or `null` when nothing is
  /// loaded.
  final int? currentIndex;

  /// The current entry's position at the moment the snapshot was taken.
  ///
  /// A controller showing a moving progress bar extrapolates from here
  /// using its own clock while [status] is playing, rather than asking
  /// for a snapshot every second.
  final Duration position;

  final bool shuffleEnabled;
  final RepeatMode repeatMode;

  /// The target's output volume in `0.0`-`1.0`, or `null` when it does
  /// not expose one (a device whose volume is the amplifier's business).
  /// `null` is the reason a volume control is hidden rather than shown
  /// doing nothing.
  final double? volume;

  /// The name of what this queue was started from, when it has one — see
  /// `QueueOrigin`. Carried as a name only: a controller displays "from
  /// Late Night", it does not navigate into the target's listening
  /// context.
  final String? originName;

  /// Jellyfin SyncPlay group currently producing this queue, when any.
  final String? syncGroupId;

  RemoteQueueEntry? get currentEntry {
    final index = currentIndex;
    if (index == null || index < 0 || index >= queue.length) return null;
    return queue[index];
  }

  bool get isEmpty => queue.isEmpty;

  /// Whether this snapshot describes a device that is currently making
  /// sound — what a picker marks as the active player.
  bool get isActivePlayer => status.isActive;

  /// Whether [other] describes the same session at a later revision.
  ///
  /// The test a controller applies to every arriving snapshot: messages
  /// can arrive out of order, and the newest one received is not
  /// necessarily the newest one taken.
  bool supersededBy(RemotePlaybackSnapshot other) =>
      other.sessionId == sessionId && other.revision > revision;

  RemotePlaybackSnapshot copyWith({
    StateRevision? revision,
    PlaybackStatus? status,
    List<RemoteQueueEntry>? queue,
    int? currentIndex,
    bool clearCurrentIndex = false,
    Duration? position,
    bool? shuffleEnabled,
    RepeatMode? repeatMode,
    double? volume,
    String? originName,
    bool clearOrigin = false,
    String? syncGroupId,
    bool clearSyncGroupId = false,
  }) {
    return RemotePlaybackSnapshot(
      scope: scope,
      sessionId: sessionId,
      revision: revision ?? this.revision,
      status: status ?? this.status,
      queue: queue ?? this.queue,
      currentIndex: clearCurrentIndex
          ? null
          : (currentIndex ?? this.currentIndex),
      position: position ?? this.position,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      volume: volume ?? this.volume,
      originName: clearOrigin ? null : (originName ?? this.originName),
      syncGroupId: clearSyncGroupId ? null : (syncGroupId ?? this.syncGroupId),
    );
  }

  /// The envelope payload form.
  ///
  /// [scope] is deliberately not written here: the envelope already
  /// carries it and checks it before the payload is read, and a payload
  /// that could disagree with its envelope would be a second place for
  /// account isolation to go wrong.
  Map<String, Object?> toPayload() => {
    'session': sessionId,
    'revision': revision.value,
    'status': status.name,
    'queue': [for (final entry in queue) entry.toJson()],
    if (currentIndex != null) 'currentIndex': currentIndex,
    'positionMs': position.inMilliseconds,
    'shuffleEnabled': shuffleEnabled,
    'repeatMode': repeatMode.name,
    if (volume != null) 'volume': volume,
    if (originName != null) 'originName': originName,
    if (syncGroupId != null) 'syncGroupId': syncGroupId,
  };

  /// Reverses [toPayload] against the envelope's already-verified
  /// [scope]. Returns `null` for anything unreadable.
  static RemotePlaybackSnapshot? tryDecode(
    Map<String, Object?> payload, {
    required ConnectedPlaybackScope scope,
  }) {
    final sessionId = payload['session'];
    final revision = StateRevision.tryParse(payload['revision']);
    if (sessionId is! String || sessionId.isEmpty || revision == null) {
      return null;
    }
    final statusName = payload['status'];
    PlaybackStatus? status;
    for (final candidate in PlaybackStatus.values) {
      if (candidate.name == statusName) status = candidate;
    }
    if (status == null) return null;

    final rawQueue = payload['queue'];
    final queue = <RemoteQueueEntry>[];
    if (rawQueue is List) {
      for (final raw in rawQueue) {
        final entry = RemoteQueueEntry.tryDecode(raw);
        if (entry == null) return null;
        queue.add(entry.forLocalServer(scope.serverId));
      }
    }

    RepeatMode repeatMode = RepeatMode.off;
    for (final candidate in RepeatMode.values) {
      if (candidate.name == payload['repeatMode']) repeatMode = candidate;
    }

    final currentIndex = payload['currentIndex'];
    final positionMs = payload['positionMs'];
    final volume = payload['volume'];
    final originName = payload['originName'];
    final syncGroupId = payload['syncGroupId'];
    return RemotePlaybackSnapshot(
      scope: scope,
      sessionId: sessionId,
      revision: revision,
      status: status,
      queue: queue,
      currentIndex:
          currentIndex is int &&
              currentIndex >= 0 &&
              currentIndex < queue.length
          ? currentIndex
          : null,
      position: positionMs is int && positionMs > 0
          ? Duration(milliseconds: positionMs)
          : Duration.zero,
      shuffleEnabled: payload['shuffleEnabled'] == true,
      repeatMode: repeatMode,
      volume: volume is num ? volume.toDouble().clamp(0.0, 1.0) : null,
      originName: originName is String && originName.isNotEmpty
          ? originName
          : null,
      syncGroupId: syncGroupId is String && syncGroupId.isNotEmpty
          ? syncGroupId
          : null,
    );
  }

  @override
  List<Object?> get props => [
    scope,
    sessionId,
    revision,
    status,
    queue,
    currentIndex,
    position,
    shuffleEnabled,
    repeatMode,
    volume,
    originName,
    syncGroupId,
  ];
}
