import 'package:equatable/equatable.dart';

import '../../core/result/partial.dart';
import '../playback/repeat_mode.dart';
import 'ConnectedPlaybackLimits.dart';
import 'ConnectedPlaybackScope.dart';
import 'RemoteQueueEntry.dart';
import 'StateRevision.dart';
import 'transfer_refusal.dart';

/// The four messages a handoff is made of.
///
/// `Roadmap to v0.6.md` gives "transfer playback" a strict meaning: the
/// destination receives the ordered queue, current item, position,
/// shuffle and repeat state, "and becomes the only playback owner after
/// it confirms that it is ready". Merely opening the current song
/// elsewhere is not a transfer.
///
/// That sentence is why there are four messages rather than one. A single
/// "play this over there" would have to either stop the source before
/// knowing whether the target can comply — losing the listener's music
/// when it cannot — or leave the source playing until it hears back,
/// which is two devices playing at once. Splitting the conversation into
/// offer, readiness, commit and result puts exactly one uncertain window
/// in the middle, and gives the source something to resume from if that
/// window closes badly.

/// Step one, source to target: "here is a queue — can you play it?"
///
/// Sent while the source is still playing. Carries everything the target
/// needs to answer honestly, and nothing it could not have read from the
/// server itself (see [RemoteQueueEntry]).
class TransferOffer extends Equatable {
  const TransferOffer({
    required this.transferId,
    required this.scope,
    required this.sourceSessionId,
    required this.targetSessionId,
    required this.entries,
    required this.startIndex,
    this.startPosition = Duration.zero,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.originName,
    this.startPlaying = true,
    this.lifetime = ConnectedPlaybackLimits.handoffStepTimeout,
  });

  /// Identifies this handoff across all four messages. A retried offer
  /// keeps its id, so a target that already prepared for it answers the
  /// same way rather than preparing twice.
  final String transferId;

  final ConnectedPlaybackScope scope;
  final String sourceSessionId;
  final String targetSessionId;

  /// The queue in play order, complete. Never a window and never a
  /// filtered subset: the target either takes all of it or refuses.
  final List<RemoteQueueEntry> entries;

  final int startIndex;

  /// Where the current entry is. The difference between continuing a
  /// song on another device and starting it again.
  final Duration startPosition;

  final bool shuffleEnabled;
  final RepeatMode repeatMode;

  /// The listening context's name, when the queue has one — a transfer
  /// does not restart the listening context (`QueueOrigin`).
  final String? originName;

  /// Whether the source was playing rather than paused (v0.5.4) — the
  /// other half of [startPosition] in "transfer playback exactly as it
  /// is": a handoff started from a paused queue hands over paused, not
  /// resumed.
  final bool startPlaying;

  final Duration lifetime;

  /// Whether this offer is within the bounds both sides enforce.
  ///
  /// Checked by the source before sending, so an over-long queue is
  /// refused while the music is still playing rather than after the
  /// listener has chosen a device.
  bool get isWithinLimits =>
      entries.isNotEmpty &&
      entries.length <= ConnectedPlaybackLimits.maxQueueEntries &&
      startIndex >= 0 &&
      startIndex < entries.length;

  @override
  List<Object?> get props => [
    transferId,
    scope,
    sourceSessionId,
    targetSessionId,
    entries,
    startIndex,
    startPosition,
    shuffleEnabled,
    repeatMode,
    originName,
    startPlaying,
    lifetime,
  ];
}

/// Step two, target to source: "yes, all of it" or "no, and here is
/// exactly what I could not do".
///
/// The source is still playing when this arrives. A [refusal] therefore
/// costs the listener nothing but an explanation.
class TransferReadiness extends Equatable {
  const TransferReadiness({
    required this.transferId,
    required this.targetSessionId,
    required this.isReady,
    this.refusal,
    this.unresolvable = const [],
    this.message,
  });

  factory TransferReadiness.ready({
    required String transferId,
    required String targetSessionId,
  }) => TransferReadiness(
    transferId: transferId,
    targetSessionId: targetSessionId,
    isReady: true,
  );

  /// A refusal, naming the entries responsible.
  ///
  /// [unresolvable] reuses [UnavailableItem] — the same type a partially
  /// readable album already reports its missing tracks with, carrying an
  /// id, a reason and the position in the collection. The position is the
  /// point: "three tracks cannot be played there" is a summary, "entries
  /// 4, 9 and 12" is something the listener can look at and decide about.
  factory TransferReadiness.refused({
    required String transferId,
    required String targetSessionId,
    required TransferRefusal refusal,
    List<UnavailableItem> unresolvable = const [],
    String? message,
  }) => TransferReadiness(
    transferId: transferId,
    targetSessionId: targetSessionId,
    isReady: false,
    refusal: refusal,
    unresolvable: unresolvable,
    message: message,
  );

  final String transferId;
  final String targetSessionId;

  /// True only when the target can reproduce the **whole** queue.
  final bool isReady;

  final TransferRefusal? refusal;

  /// The entries the target could not resolve, with their positions in
  /// the offered queue.
  final List<UnavailableItem> unresolvable;

  final String? message;

  @override
  List<Object?> get props => [
    transferId,
    targetSessionId,
    isReady,
    refusal,
    unresolvable,
    message,
  ];
}

/// Step three, source to target: "it is yours."
///
/// Sent only after a ready [TransferReadiness]. The source stops at this
/// point, which is what makes [position] worth re-sending — the song has
/// moved on since the offer was composed, and the listener should not
/// hear a few seconds twice.
class TransferCommit extends Equatable {
  const TransferCommit({
    required this.transferId,
    required this.sourceSessionId,
    required this.targetSessionId,
    required this.position,
  });

  final String transferId;
  final String sourceSessionId;
  final String targetSessionId;

  /// The current entry's position at the moment the source let go.
  final Duration position;

  @override
  List<Object?> get props => [
    transferId,
    sourceSessionId,
    targetSessionId,
    position,
  ];
}

/// Step four, target to source: "I am playing it, and this is my
/// revision."
///
/// Until this arrives, the source is entitled to resume — which is the
/// whole reason the step exists. A lost acknowledgement must resolve to
/// one device playing, and the safe direction is the device the listener
/// was already next to.
class TransferResult extends Equatable {
  const TransferResult({
    required this.transferId,
    required this.targetSessionId,
    required this.accepted,
    this.revision,
    this.refusal,
    this.message,
  });

  factory TransferResult.playing({
    required String transferId,
    required String targetSessionId,
    required StateRevision revision,
  }) => TransferResult(
    transferId: transferId,
    targetSessionId: targetSessionId,
    accepted: true,
    revision: revision,
  );

  factory TransferResult.failed({
    required String transferId,
    required String targetSessionId,
    required TransferRefusal refusal,
    String? message,
  }) => TransferResult(
    transferId: transferId,
    targetSessionId: targetSessionId,
    accepted: false,
    refusal: refusal,
    message: message,
  );

  final String transferId;
  final String targetSessionId;

  /// Whether the target is now the playback owner.
  final bool accepted;

  /// The target's revision once it owned the queue — the baseline the
  /// source uses as it becomes a controller, without a further round
  /// trip.
  final StateRevision? revision;

  final TransferRefusal? refusal;
  final String? message;

  @override
  List<Object?> get props => [
    transferId,
    targetSessionId,
    accepted,
    revision,
    refusal,
    message,
  ];
}

/// Encoding and decoding for the four handoff messages (v0.5.4).
///
/// `PlaybackTransfer.dart` defines the *conversation*; this is where it is
/// framed on the wire, kept beside the family for the same reason
/// `RemoteCommandCodec` is — a message and its codec are one thing to
/// keep in sync, not two files that can drift apart.
///
/// [ConnectedPlaybackEnvelope] already carries [scope] and the sender's
/// session id and verifies both before a payload is ever read, so neither
/// is repeated in these payloads; each `tryDecode` takes them from the
/// envelope instead.
extension TransferOfferCodec on TransferOffer {
  Map<String, Object?> toPayload() => {
    'transferId': transferId,
    'target': targetSessionId,
    'entries': [for (final entry in entries) entry.toJson()],
    'startIndex': startIndex,
    'startPositionMs': startPosition.inMilliseconds,
    'shuffleEnabled': shuffleEnabled,
    'repeatMode': repeatMode.name,
    'startPlaying': startPlaying,
    'lifetimeMs': lifetime.inMilliseconds,
    if (originName != null) 'originName': originName,
  };

  /// Reverses [toPayload]. [scope] and [sourceSessionId] come from the
  /// envelope, already verified. Returns `null` for anything unreadable —
  /// never a partial offer with some entries silently dropped.
  static TransferOffer? tryDecode(
    Map<String, Object?> payload, {
    required ConnectedPlaybackScope scope,
    required String sourceSessionId,
  }) {
    final transferId = _string(payload['transferId']);
    final target = _string(payload['target']);
    final startIndex = payload['startIndex'];
    if (transferId == null || target == null || startIndex is! int) {
      return null;
    }
    final rawEntries = payload['entries'];
    if (rawEntries is! List || rawEntries.isEmpty) return null;
    final entries = <RemoteQueueEntry>[];
    for (final raw in rawEntries) {
      final entry = RemoteQueueEntry.tryDecode(raw);
      if (entry == null) return null;
      entries.add(entry.forLocalServer(scope.serverId));
    }
    final positionMs = payload['startPositionMs'];
    final lifetimeMs = payload['lifetimeMs'];
    return TransferOffer(
      transferId: transferId,
      scope: scope,
      sourceSessionId: sourceSessionId,
      targetSessionId: target,
      entries: entries,
      startIndex: startIndex,
      startPosition: positionMs is int
          ? Duration(milliseconds: positionMs)
          : Duration.zero,
      shuffleEnabled: payload['shuffleEnabled'] == true,
      repeatMode: _repeatMode(payload['repeatMode']),
      originName: _string(payload['originName']),
      startPlaying: payload['startPlaying'] != false,
      lifetime: lifetimeMs is int
          ? Duration(milliseconds: lifetimeMs)
          : ConnectedPlaybackLimits.handoffStepTimeout,
    );
  }
}

extension TransferReadinessCodec on TransferReadiness {
  Map<String, Object?> toPayload() => {
    'transferId': transferId,
    'target': targetSessionId,
    'ready': isReady,
    if (refusal != null) 'refusal': refusal!.name,
    if (unresolvable.isNotEmpty)
      'unresolvable': [for (final item in unresolvable) _encodeItem(item)],
    if (message != null) 'message': message,
  };

  /// Reverses [toPayload]. [targetSessionId] is trusted from the envelope
  /// sender rather than re-read from the payload — the answering device
  /// is whoever sent this message.
  static TransferReadiness? tryDecode(
    Map<String, Object?> payload, {
    required String targetSessionId,
  }) {
    final transferId = _string(payload['transferId']);
    if (transferId == null) return null;
    final isReady = payload['ready'] == true;
    if (isReady) {
      return TransferReadiness.ready(
        transferId: transferId,
        targetSessionId: targetSessionId,
      );
    }
    final rawUnresolvable = payload['unresolvable'];
    final unresolvable = <UnavailableItem>[];
    if (rawUnresolvable is List) {
      for (final raw in rawUnresolvable) {
        final item = _decodeItem(raw);
        if (item != null) unresolvable.add(item);
      }
    }
    return TransferReadiness.refused(
      transferId: transferId,
      targetSessionId: targetSessionId,
      refusal: _refusal(payload['refusal']) ?? TransferRefusal.playbackFailed,
      unresolvable: unresolvable,
      message: _string(payload['message']),
    );
  }
}

extension TransferCommitCodec on TransferCommit {
  Map<String, Object?> toPayload() => {
    'transferId': transferId,
    'target': targetSessionId,
    'positionMs': position.inMilliseconds,
  };

  /// Reverses [toPayload]. [sourceSessionId] comes from the envelope, like
  /// [TransferOfferCodec.tryDecode]; [targetSessionId] is this device's
  /// own — the commit already reached us, so it named us.
  static TransferCommit? tryDecode(
    Map<String, Object?> payload, {
    required String sourceSessionId,
    required String targetSessionId,
  }) {
    final transferId = _string(payload['transferId']);
    if (transferId == null) return null;
    final positionMs = payload['positionMs'];
    return TransferCommit(
      transferId: transferId,
      sourceSessionId: sourceSessionId,
      targetSessionId: targetSessionId,
      position: positionMs is int
          ? Duration(milliseconds: positionMs)
          : Duration.zero,
    );
  }
}

extension TransferResultCodec on TransferResult {
  Map<String, Object?> toPayload() => {
    'transferId': transferId,
    'target': targetSessionId,
    'accepted': accepted,
    if (revision != null) 'revision': revision!.value,
    if (refusal != null) 'refusal': refusal!.name,
    if (message != null) 'message': message,
  };

  /// Reverses [toPayload]. [targetSessionId] is trusted from the envelope
  /// sender, on the same terms as [TransferReadinessCodec.tryDecode].
  static TransferResult? tryDecode(
    Map<String, Object?> payload, {
    required String targetSessionId,
  }) {
    final transferId = _string(payload['transferId']);
    if (transferId == null) return null;
    if (payload['accepted'] == true) {
      final revision = StateRevision.tryParse(payload['revision']);
      if (revision == null) return null;
      return TransferResult.playing(
        transferId: transferId,
        targetSessionId: targetSessionId,
        revision: revision,
      );
    }
    return TransferResult.failed(
      transferId: transferId,
      targetSessionId: targetSessionId,
      refusal: _refusal(payload['refusal']) ?? TransferRefusal.playbackFailed,
      message: _string(payload['message']),
    );
  }
}

Map<String, Object?> _encodeItem(UnavailableItem item) => {
  'id': item.id,
  'reason': item.reason,
  if (item.position != null) 'position': item.position,
};

UnavailableItem? _decodeItem(Object? raw) {
  if (raw is! Map) return null;
  final id = _string(raw['id']);
  final reason = _string(raw['reason']);
  if (id == null || reason == null) return null;
  final position = raw['position'];
  return UnavailableItem(
    id: id,
    reason: reason,
    position: position is int ? position : null,
  );
}

RepeatMode _repeatMode(Object? name) {
  for (final candidate in RepeatMode.values) {
    if (candidate.name == name) return candidate;
  }
  return RepeatMode.off;
}

TransferRefusal? _refusal(Object? name) {
  for (final candidate in TransferRefusal.values) {
    if (candidate.name == name) return candidate;
  }
  return null;
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
