/// How [PlaybackQueue] behaves once it reaches the end of its play order.
enum RepeatMode {
  /// Stop after the last entry.
  off,

  /// Replay the current entry indefinitely.
  one,

  /// Return to the first entry in the play order and continue.
  all;

  bool get repeatsCurrentEntry => this == one;
}
