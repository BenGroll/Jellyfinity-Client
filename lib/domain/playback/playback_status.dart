/// What a [PlaybackEngine] is currently doing with its current source.
///
/// Deliberately coarser than `just_audio`'s own processing-state/playing
/// split: a Now Playing screen needs to draw one of a handful of states,
/// not reconstruct them from two flags.
enum PlaybackStatus {
  /// No source loaded — nothing has ever played, or [PlaybackEngine.stop]
  /// was called.
  idle,

  /// A source is being loaded for the first time.
  loading,

  /// Playing, but momentarily stalled waiting for data.
  buffering,

  playing,
  paused,

  /// The current source reached its end. [PlaybackEngine] does not decide
  /// what plays next — that is [PlaybackQueue]'s job, applied by
  /// `PlaybackCubit`.
  completed;

  bool get isActive => this == playing || this == buffering;
}
