import 'package:equatable/equatable.dart';

import '../../domain/playback/PlaybackFailure.dart';
import '../../domain/playback/PlaybackQueue.dart';
import '../../domain/playback/playback_status.dart';
import '../../domain/playback/QueueEntry.dart';

/// [PlaybackCubit]'s whole-app playback state — the queue plus what the
/// engine is currently doing with it.
///
/// No `copyWith`: [duration] and [lastFailure] both need to be settable
/// back to `null` (an unknown duration, no pending failure to show), and
/// every field genuinely changes at some emit site, so a positional
/// rebuild at each call site is clearer than a nullable-aware `copyWith`.
class PlaybackUiState extends Equatable {
  const PlaybackUiState({
    this.queue = PlaybackQueue.empty,
    this.status = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration,
    this.lastFailure,
    this.systemVolume,
  });

  final PlaybackQueue queue;
  final PlaybackStatus status;

  /// The current entry's playback position.
  final Duration position;

  /// The current entry's total duration, once the engine knows it.
  final Duration? duration;

  /// The most recent source failure, if any — a mini-player/Now Playing
  /// screen listens for this to show a transient "couldn't play that
  /// track" notice. The failed entry itself is already marked
  /// unavailable in [queue]; this is only for the one-off notice.
  final PlaybackFailure? lastFailure;

  /// This device's own output volume, as a 0.0-1.0 fraction of the
  /// platform's own volume range (v0.6.0) — never crossfade/normalization
  /// gain, which are internal to the mix and not something another device
  /// can see or set. `null` on a platform with no settable system volume
  /// to report, which is why `PlaybackEngine.systemVolume` returning
  /// `null` is "absent," not zero.
  ///
  /// Every emit site threads this forward explicitly (there is no
  /// `copyWith` — see the class doc) so an ordinary position/status update
  /// never wipes out the last known volume; only [PlaybackCubit]'s own
  /// volume handling ever changes it.
  final double? systemVolume;

  QueueEntry? get currentEntry => queue.currentEntry;

  bool get hasQueue => !queue.isEmpty;

  bool get isPlaying =>
      status == PlaybackStatus.playing || status == PlaybackStatus.buffering;

  @override
  List<Object?> get props => [
    queue,
    status,
    position,
    duration,
    lastFailure,
    systemVolume,
  ];
}
