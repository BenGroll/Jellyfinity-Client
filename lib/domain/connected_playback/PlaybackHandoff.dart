import 'package:equatable/equatable.dart';

import 'ConnectedPlaybackLimits.dart';
import 'ElapsedClock.dart';
import 'PlaybackTransfer.dart';
import 'StateRevision.dart';
import 'transfer_refusal.dart';
import 'transfer_stage.dart';

/// The source side of a handoff, as a state machine.
///
/// The arc's hardest invariant is a negative one: "two devices must never
/// continue playing because an acknowledgement was lost". A negative
/// invariant cannot be tested by doing the happy path and hoping, so the
/// rule is built into the type instead — [TransferStage] orders the steps
/// so that the source only stops once the target has said it is ready,
/// and every exit from the one uncertain stage leads either to the target
/// playing or to the source playing again.
///
/// Pure and synchronous: it takes events in and returns the decision the
/// caller must carry out. It never stops or starts audio itself, which is
/// what lets every branch — including the lost-acknowledgement branch
/// that is nearly impossible to provoke on real hardware — be tested in
/// milliseconds.
///
/// Timeouts are measured with [ElapsedClock], not a wall clock, for the
/// reason that file explains. [expired] is asked by whatever drives the
/// handoff (a timer in v0.5.4); the state machine itself only compares
/// two readings of one monotonic clock.
class PlaybackHandoff {
  PlaybackHandoff({required this.clock, Duration? stepTimeout})
    : _stepTimeout = stepTimeout ?? ConnectedPlaybackLimits.handoffStepTimeout;

  /// This device's monotonic clock. Public because a handoff's timeouts
  /// are part of what a caller drives, not an implementation detail.
  final ElapsedClock clock;

  final Duration _stepTimeout;

  TransferStage _stage = TransferStage.idle;
  TransferOffer? _offer;
  Duration _stageEnteredAt = Duration.zero;
  HandoffResumeState? _resumeState;
  TransferRefusal? _refusal;
  StateRevision? _targetRevision;

  TransferStage get stage => _stage;

  TransferOffer? get offer => _offer;

  /// Why the transfer did not happen, once it has not happened.
  TransferRefusal? get refusal => _refusal;

  /// The target's revision after it took over — the baseline this device
  /// uses as it becomes a controller.
  StateRevision? get targetRevision => _targetRevision;

  /// What the source must restore if it has to resume.
  ///
  /// Captured before the source gives up playback and held until the
  /// handoff finishes. This is the whole safety net: without it, "resume
  /// where we were" would mean re-reading a queue that has already been
  /// torn down.
  HandoffResumeState? get resumeState => _resumeState;

  /// Whether the current step has outrun [_stepTimeout].
  ///
  /// Only meaningful while a step is in flight; a finished handoff never
  /// expires.
  bool get expired =>
      _stage.isInFlight && clock.elapsed - _stageEnteredAt > _stepTimeout;

  /// Begins a handoff. The source keeps playing.
  ///
  /// Refuses immediately — before anything stops — when the offer is
  /// outside the agreed bounds or another handoff is already in flight.
  /// Both are the arc's "refuse a transfer before stopping the source"
  /// rule applied to the cases the source can decide by itself.
  HandoffDecision begin(TransferOffer offer, HandoffResumeState resumeState) {
    if (_stage.isInFlight) {
      return HandoffDecision.refused(TransferRefusal.busy);
    }
    if (!offer.isWithinLimits) {
      return _finish(
        TransferStage.resumedAtSource,
        TransferRefusal.queueTooLarge,
      );
    }
    _offer = offer;
    _resumeState = resumeState;
    _refusal = null;
    _targetRevision = null;
    _enter(TransferStage.offering);
    return const HandoffDecision(action: HandoffAction.sendOffer);
  }

  /// The target's answer to the offer. The source is still playing.
  HandoffDecision onReadiness(TransferReadiness readiness) {
    if (_stage != TransferStage.offering) return _ignore();
    if (readiness.transferId != _offer?.transferId) return _ignore();

    if (!readiness.isReady) {
      // Nothing to restore: the source never stopped. The caller shows
      // the refusal and the music keeps playing.
      return _finish(
        TransferStage.resumedAtSource,
        readiness.refusal ?? TransferRefusal.playbackFailed,
        alreadyPlaying: true,
      );
    }
    _enter(TransferStage.prepared);
    return const HandoffDecision(action: HandoffAction.commit);
  }

  /// Yields ownership: the caller stops local playback and sends
  /// [TransferCommit].
  ///
  /// The only transition that costs the listener their audio, and it is
  /// deliberately a separate call from [onReadiness] rather than a
  /// side effect of it — stopping playback is an action, and an action
  /// should be something the caller decided to take.
  HandoffDecision commit() {
    if (_stage != TransferStage.prepared) return _ignore();
    _enter(TransferStage.committing);
    return const HandoffDecision(action: HandoffAction.stopLocalPlayback);
  }

  /// The target's final word.
  HandoffDecision onResult(TransferResult result) {
    if (_stage != TransferStage.committing) return _ignore();
    if (result.transferId != _offer?.transferId) return _ignore();

    if (result.accepted) {
      _targetRevision = result.revision;
      return _finish(TransferStage.completed, null);
    }
    return _finish(
      TransferStage.resumedAtSource,
      result.refusal ?? TransferRefusal.playbackFailed,
    );
  }

  /// The current step ran out of time.
  ///
  /// The branch that matters: a timeout in [TransferStage.committing]
  /// means the source has already stopped and has no idea whether the
  /// target started. It resumes. Resuming when the target did in fact
  /// start produces two players for as long as it takes the target's
  /// late result to arrive — which the caller ends by stopping the
  /// *loser*, this device, on [onResult]. Choosing the other way round —
  /// staying silent and hoping — produces a listener whose music simply
  /// stopped, with nothing to press.
  HandoffDecision onTimeout() {
    if (!_stage.isInFlight) return _ignore();
    return _finish(
      TransferStage.resumedAtSource,
      TransferRefusal.timedOut,
      alreadyPlaying: _stage.sourceStillOwnsPlayback,
    );
  }

  /// The listener changed their mind. Only possible before the commit;
  /// after it, ownership is in flight and cancelling would be a third
  /// outcome for the same uncertain window.
  HandoffDecision cancel() {
    if (!_stage.isInFlight) return _ignore();
    if (_stage == TransferStage.committing) return _ignore();
    return _finish(
      TransferStage.resumedAtSource,
      TransferRefusal.cancelled,
      alreadyPlaying: true,
    );
  }

  /// A late [TransferResult] for a handoff this device has already given
  /// up on and resumed from.
  ///
  /// The other half of the two-players case in [onTimeout]: the target
  /// did start after all. This device, having resumed, is the one that
  /// must stop.
  HandoffDecision onLateResult(TransferResult result) {
    if (_stage != TransferStage.resumedAtSource) return _ignore();
    if (result.transferId != _offer?.transferId) return _ignore();
    if (!result.accepted) return _ignore();
    _targetRevision = result.revision;
    _stage = TransferStage.completed;
    _refusal = null;
    _resumeState = null;
    return const HandoffDecision(action: HandoffAction.stopLocalPlayback);
  }

  void _enter(TransferStage stage) {
    _stage = stage;
    _stageEnteredAt = clock.elapsed;
  }

  HandoffDecision _finish(
    TransferStage stage,
    TransferRefusal? refusal, {
    bool alreadyPlaying = false,
  }) {
    _stage = stage;
    _refusal = refusal;
    final resume = _resumeState;
    if (stage != TransferStage.resumedAtSource || alreadyPlaying) {
      _resumeState = null;
      return HandoffDecision(
        action: stage == TransferStage.completed
            ? HandoffAction.becomeController
            : HandoffAction.none,
        refusal: refusal,
      );
    }
    _resumeState = null;
    return HandoffDecision(
      action: HandoffAction.resumeLocalPlayback,
      refusal: refusal,
      resumeState: resume,
    );
  }

  HandoffDecision _ignore() =>
      const HandoffDecision(action: HandoffAction.none);
}

/// What the caller should do about the event it just reported.
enum HandoffAction {
  /// Nothing — the event was for a handoff that is no longer in flight,
  /// or the state machine has already dealt with it.
  none,

  sendOffer,

  /// The target is ready. Call [PlaybackHandoff.commit] when the caller
  /// is ready to give up audio.
  commit,

  /// Stop local playback and hand ownership over.
  stopLocalPlayback,

  /// Restore playback from `HandoffDecision.resumeState`. The transfer
  /// did not happen.
  resumeLocalPlayback,

  /// The target owns playback. This device is now a controller.
  becomeController,
}

/// One instruction out of the state machine.
class HandoffDecision extends Equatable {
  const HandoffDecision({required this.action, this.refusal, this.resumeState});

  factory HandoffDecision.refused(TransferRefusal refusal) =>
      HandoffDecision(action: HandoffAction.none, refusal: refusal);

  final HandoffAction action;

  /// Set whenever the transfer will not happen, so the caller has
  /// something specific to show.
  final TransferRefusal? refusal;

  /// Present only with [HandoffAction.resumeLocalPlayback].
  final HandoffResumeState? resumeState;

  @override
  List<Object?> get props => [action, refusal, resumeState];
}

/// Enough of the source's playback to put it back exactly as it was.
///
/// Held by value rather than as "whatever the queue happens to be": by
/// the time a resume is needed the local queue may have been torn down,
/// and restoring it from itself would restore nothing.
class HandoffResumeState extends Equatable {
  const HandoffResumeState({
    required this.currentIndex,
    required this.position,
    required this.wasPlaying,
  });

  final int currentIndex;
  final Duration position;

  /// Whether the source was playing rather than paused. A handoff
  /// attempted from a paused queue resumes paused — restoring "as it
  /// was" includes not starting music the listener had stopped.
  final bool wasPlaying;

  @override
  List<Object?> get props => [currentIndex, position, wasPlaying];
}
