/// Where a handoff has got to.
///
/// The arc's rule — "a handoff is prepare, commit, and acknowledge", and
/// "two devices must never continue playing because an acknowledgement
/// was lost" — is a state machine, so it is written as one. The important
/// property is visible in the order: the source keeps playing through
/// [offering] and only gives up its audio at [committing], after the
/// target has already said it is ready. Every way out of [committing]
/// leads either to the target playing ([completed]) or the source playing
/// again ([resumedAtSource]) — never to both, and never to neither.
enum TransferStage {
  /// Nothing in flight.
  idle,

  /// The offer has been sent; the source is still playing.
  offering,

  /// The target answered that it can reproduce the queue. The source is
  /// still playing, and now has an answer it can commit on.
  prepared,

  /// Ownership has been yielded: the source has stopped and is waiting
  /// for the target to confirm. The only stage in which nobody is
  /// playing, and the only one with a hard deadline attached.
  committing,

  /// The target confirmed. It owns the queue; the source is a controller.
  completed,

  /// The transfer did not happen and the source is playing again — from
  /// a refusal, a timeout, or a lost acknowledgement. Not an error state
  /// the user has to clear: the music is playing where it was.
  resumedAtSource,

  /// The transfer did not happen and the source could not resume either.
  /// Rare and worth saying plainly rather than pretending playback is
  /// fine.
  failed;

  /// Whether the source still owns playback at this stage.
  bool get sourceStillOwnsPlayback =>
      this == idle ||
      this == offering ||
      this == prepared ||
      this == resumedAtSource;

  /// Whether a handoff is under way and a second one must be refused.
  bool get isInFlight =>
      this == offering || this == prepared || this == committing;

  bool get isFinished =>
      this == completed || this == resumedAtSource || this == failed;
}
