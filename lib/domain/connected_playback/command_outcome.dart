/// What a target did with a command.
///
/// Every member is a distinct thing the controller should do next, which
/// is the test for whether a failure deserves its own member here rather
/// than a message on a generic one. `CONTEXT.md`'s "normalize failures"
/// rule applies as much to a control channel as to an HTTP call: a
/// controller that only knows "it did not work" can only offer a retry,
/// and a retry is the wrong answer to four of the cases below.
enum CommandOutcome {
  /// Applied. The acknowledgement carries the revision it produced.
  applied,

  /// Already applied — this id was seen before. The acknowledgement
  /// carries the revision the *first* attempt produced, so a retried
  /// command leaves the controller in the same state a delivered one
  /// would have. Not a failure.
  duplicate,

  /// The command was composed against a revision that has moved on.
  /// The controller resynchronizes and decides again; it must not
  /// re-send the same instruction blind.
  stale,

  /// Delivered, but too late to still mean what the listener meant.
  /// Dropped; the controller resynchronizes rather than retrying.
  expired,

  /// The target does not know this command — an older build being driven
  /// by a newer one. Permanent for this pair: do not retry, and stop
  /// offering the control.
  unsupported,

  /// The target speaks a different protocol major version. Permanent
  /// until one side is updated.
  incompatible,

  /// The command named a different server or profile. Dropped without
  /// being applied; never retried, and worth logging, because it means
  /// something outlived an account switch.
  outOfScope,

  /// The command named a session this target is not. Usually a
  /// reconnection: the controller rediscovers the device's current
  /// session and composes again.
  wrongTarget,

  /// The server or the target refused on permission grounds. The listener
  /// has to change something on the server; retrying cannot help.
  notPermitted,

  /// The command exceeded an agreed bound — too many queue entries, too
  /// large a payload. Deterministic: the same command will always be
  /// refused.
  tooLarge,

  /// Well-formed but not applicable to the current state — a remove at an
  /// index the queue does not have, a jump into an empty queue.
  rejected;

  /// Whether the target's state now reflects this command.
  bool get isAccepted => this == applied || this == duplicate;

  /// Whether the controller's projection is known to be wrong and must be
  /// refreshed before composing another structural command.
  bool get requiresResync =>
      this == stale || this == expired || this == wrongTarget;

  /// Whether re-sending could ever succeed. False for every permanent
  /// refusal, so a controller does not sit in a retry loop against a
  /// device that will never say yes.
  bool get isRetryable => this == expired;
}
