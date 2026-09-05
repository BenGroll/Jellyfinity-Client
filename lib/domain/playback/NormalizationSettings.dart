import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Whether [PlaybackEngine] should apply each source's loudness gain when
/// setting playback volume (v0.1.4).
///
/// A playback *preference*, the same architectural slot as
/// [CrossfadeSettings]: it says nothing about where the gain value comes
/// from (that is [PlaybackSource.normalizationGain], resolved from
/// Jellyfin's own loudness analysis) or which source is playing (that
/// remains `PlaybackQueue`'s answer), only whether the engine should use
/// the number it is already handed.
///
/// [disabled] is the default and means every source plays at its
/// unadjusted volume.
class NormalizationSettings extends Equatable {
  const NormalizationSettings({required this.enabled});

  static const NormalizationSettings disabled = NormalizationSettings(
    enabled: false,
  );

  final bool enabled;

  NormalizationSettings copyWith({bool? enabled}) =>
      NormalizationSettings(enabled: enabled ?? this.enabled);

  /// The linear volume multiplier to apply for a source whose Jellyfin
  /// `NormalizationGain` is [gainDb].
  ///
  /// Clamped to never exceed unity: [gainDb] is positive for a track
  /// quieter than the reference loudness, and boosting it back up risks
  /// clipping without a limiter, which nothing downstream of this
  /// implements. Normalization therefore only ever brings loud tracks
  /// *down* toward the target — the same "never boost" choice most
  /// ReplayGain players default to. `null` (untagged or unanalyzed by
  /// the server) and disabled both mean unity: normalization has no
  /// opinion on a track it has no data for.
  double volumeFactorFor(double? gainDb) {
    if (!enabled || gainDb == null) return 1;
    final factor = math.pow(10, gainDb / 20).toDouble();
    return factor > 1 ? 1 : factor;
  }

  @override
  List<Object?> get props => [enabled];
}
