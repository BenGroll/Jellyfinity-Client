import 'package:equatable/equatable.dart';

/// How [PlaybackEngine] should transition between two consecutive
/// sources (ADR-0016).
///
/// This is a playback *preference*, not queue state: it says nothing
/// about what plays next, only about how the handover between two
/// sources sounds. That is what keeps it inside the engine seam — the
/// engine still has no idea what a queue, shuffle or repeat is.
///
/// [disabled] is the default and means the engine keeps its ordinary
/// gapless transition.
class CrossfadeSettings extends Equatable {
  const CrossfadeSettings({required this.enabled, required this.duration});

  /// Crossfade off — consecutive sources play gaplessly, back to back.
  static const CrossfadeSettings disabled = CrossfadeSettings(
    enabled: false,
    duration: defaultDuration,
  );

  /// Long enough to be clearly audible, short enough not to swallow a
  /// track's ending on the first try.
  static const Duration defaultDuration = Duration(seconds: 5);

  /// Below a second the ramp is indistinguishable from a hard cut, and
  /// past twelve seconds it overlaps more of a short track than it
  /// transitions between two.
  static const Duration minimumDuration = Duration(seconds: 1);
  static const Duration maximumDuration = Duration(seconds: 12);

  final bool enabled;

  /// How long the overlap lasts. Always within
  /// [minimumDuration]–[maximumDuration]; a value outside that range is
  /// clamped by [CrossfadeSettings.new]'s callers via [clampDuration]
  /// rather than rejected, so a stale or hand-edited stored preference
  /// degrades to the nearest usable duration instead of failing.
  final Duration duration;

  static Duration clampDuration(Duration duration) {
    if (duration < minimumDuration) return minimumDuration;
    if (duration > maximumDuration) return maximumDuration;
    return duration;
  }

  CrossfadeSettings copyWith({bool? enabled, Duration? duration}) =>
      CrossfadeSettings(
        enabled: enabled ?? this.enabled,
        duration: clampDuration(duration ?? this.duration),
      );

  /// The overlap to actually use for a source of [sourceDuration].
  ///
  /// A crossfade longer than half a track would still be fading the
  /// outgoing source in when the next one starts, so short tracks get a
  /// proportionally shorter overlap rather than no crossfade at all. A
  /// source whose duration is unknown gets none: the engine cannot know
  /// where the end is, so there is nothing to fade towards.
  Duration? effectiveDurationFor(Duration? sourceDuration) {
    if (!enabled || sourceDuration == null) return null;
    final half = sourceDuration ~/ 2;
    if (half <= Duration.zero) return null;
    return duration < half ? duration : half;
  }

  @override
  List<Object?> get props => [enabled, duration];
}
