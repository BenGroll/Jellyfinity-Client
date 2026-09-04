import 'package:equatable/equatable.dart';

/// How far the user has got through one item, and whether they finished
/// it.
///
/// Reading this is meaningful from v0.0.7 (it rides along with every item
/// the server returns). *Reporting* position back to Jellyfin needs a
/// playback session and arrives with the player in v0.0.9 — see
/// [PlaybackProgressRepository], which can already mark an item played or
/// unplayed.
class PlaybackProgress extends Equatable {
  const PlaybackProgress({
    this.position = Duration.zero,
    this.completed = false,
    this.lastPlayedAt,
  });

  /// Nothing has been played of this item.
  static const PlaybackProgress none = PlaybackProgress();

  /// How far in the user stopped.
  final Duration position;

  /// Whether the item counts as watched/listened — Jellyfin's "played"
  /// flag, which it sets near the end rather than exactly at it.
  final bool completed;

  /// When the item was last played, if the server recorded it.
  final DateTime? lastPlayedAt;

  bool get isStarted => position > Duration.zero;

  /// Whether offering "Resume" makes sense.
  bool get isResumable => isStarted && !completed;

  /// [position] as a fraction of [total], clamped to 0..1. Returns 0 for
  /// an unknown or zero-length item rather than dividing by zero.
  double fractionOf(Duration total) {
    if (total <= Duration.zero) return 0;
    final fraction = position.inMilliseconds / total.inMilliseconds;
    return fraction.clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [position, completed, lastPlayedAt];
}
