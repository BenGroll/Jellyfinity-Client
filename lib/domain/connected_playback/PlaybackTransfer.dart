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
