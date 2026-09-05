import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/playback/CrossfadeSettings.dart';
import '../../domain/playback/NormalizationSettings.dart';
import '../../domain/playback/stream_quality.dart';
import '../../infrastructure/persistence/key_value_store.dart';
import 'ShellNavigationMode.dart';

class SettingsState extends Equatable {
  const SettingsState({
    required this.navigationMode,
    required this.streamQuality,
    required this.crossfade,
    required this.normalization,
  });

  final ShellNavigationMode navigationMode;
  final StreamQuality streamQuality;
  final CrossfadeSettings crossfade;
  final NormalizationSettings normalization;

  SettingsState copyWith({
    ShellNavigationMode? navigationMode,
    StreamQuality? streamQuality,
    CrossfadeSettings? crossfade,
    NormalizationSettings? normalization,
  }) => SettingsState(
    navigationMode: navigationMode ?? this.navigationMode,
    streamQuality: streamQuality ?? this.streamQuality,
    crossfade: crossfade ?? this.crossfade,
    normalization: normalization ?? this.normalization,
  );

  @override
  List<Object?> get props => [
    navigationMode,
    streamQuality,
    crossfade,
    normalization,
  ];
}

/// The app's persisted preferences — [ShellNavigationMode],
/// [StreamQuality], [CrossfadeSettings] and [NormalizationSettings]
/// today, with room to grow the same way `AppConfig`/`KeyValueStore`
/// already do.
///
/// Every initial value is resolved once in `bootstrap()`, right after
/// `configureDependencies()` returns, so the very first frame already
/// renders/plays at the saved settings — no flash of the default followed
/// by a swap, unlike `SessionCubit`/`PlaybackCubit`'s unawaited restores,
/// which are fine to resolve after first paint.
@injectable
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(
    this._store,
    ShellNavigationMode initialNavigationMode,
    StreamQuality initialStreamQuality,
    CrossfadeSettings initialCrossfade,
    NormalizationSettings initialNormalization,
  ) : super(
        SettingsState(
          navigationMode: initialNavigationMode,
          streamQuality: initialStreamQuality,
          crossfade: initialCrossfade,
          normalization: initialNormalization,
        ),
      );

  final KeyValueStore _store;

  static const _navigationModeKey = 'settings.navigationMode';
  static const _streamQualityKey = 'settings.streamQuality';
  static const _crossfadeEnabledKey = 'settings.crossfadeEnabled';
  static const _crossfadeSecondsKey = 'settings.crossfadeSeconds';
  static const _normalizationEnabledKey = 'settings.normalizationEnabled';

  static Future<ShellNavigationMode> loadInitialNavigationMode(
    KeyValueStore store,
  ) async {
    final raw = await store.getString(_navigationModeKey);
    return ShellNavigationMode.tryParse(raw) ?? ShellNavigationMode.fallback;
  }

  static Future<StreamQuality> loadInitialStreamQuality(
    KeyValueStore store,
  ) async {
    final raw = await store.getString(_streamQualityKey);
    return StreamQuality.tryParse(raw) ?? StreamQuality.fallback;
  }

  /// Reads the crossfade preference (ADR-0016). Enabled state and
  /// duration are stored as two scalars rather than one encoded string
  /// so that turning crossfade off and on again keeps the duration the
  /// user had chosen. A missing or out-of-range duration falls back to
  /// the nearest usable one rather than disabling the feature.
  static Future<CrossfadeSettings> loadInitialCrossfade(
    KeyValueStore store,
  ) async {
    final enabled = await store.getBool(_crossfadeEnabledKey);
    final seconds = await store.getInt(_crossfadeSecondsKey);
    return CrossfadeSettings(
      enabled: enabled ?? CrossfadeSettings.disabled.enabled,
      duration: seconds == null
          ? CrossfadeSettings.defaultDuration
          : CrossfadeSettings.clampDuration(Duration(seconds: seconds)),
    );
  }

  /// Reads the normalization preference (v0.1.4). A missing value
  /// degrades to [NormalizationSettings.disabled] the same way a missing
  /// crossfade or navigation-mode value does.
  static Future<NormalizationSettings> loadInitialNormalization(
    KeyValueStore store,
  ) async {
    final enabled = await store.getBool(_normalizationEnabledKey);
    return NormalizationSettings(
      enabled: enabled ?? NormalizationSettings.disabled.enabled,
    );
  }

  Future<void> setNavigationMode(ShellNavigationMode mode) async {
    if (mode == state.navigationMode) return;
    await _store.setString(_navigationModeKey, mode.name);
    emit(state.copyWith(navigationMode: mode));
  }

  Future<void> setStreamQuality(StreamQuality quality) async {
    if (quality == state.streamQuality) return;
    await _store.setString(_streamQualityKey, quality.name);
    emit(state.copyWith(streamQuality: quality));
  }

  Future<void> setCrossfadeEnabled(bool enabled) async {
    if (enabled == state.crossfade.enabled) return;
    await _store.setBool(_crossfadeEnabledKey, enabled);
    emit(state.copyWith(crossfade: state.crossfade.copyWith(enabled: enabled)));
  }

  /// Sets the overlap length, clamped to
  /// [CrossfadeSettings.minimumDuration]–[CrossfadeSettings.maximumDuration].
  /// Persisted whether or not crossfade is currently enabled.
  Future<void> setCrossfadeDuration(Duration duration) async {
    final clamped = CrossfadeSettings.clampDuration(duration);
    if (clamped == state.crossfade.duration) return;
    await _store.setInt(_crossfadeSecondsKey, clamped.inSeconds);
    emit(
      state.copyWith(crossfade: state.crossfade.copyWith(duration: clamped)),
    );
  }

  Future<void> setNormalizationEnabled(bool enabled) async {
    if (enabled == state.normalization.enabled) return;
    await _store.setBool(_normalizationEnabledKey, enabled);
    emit(
      state.copyWith(
        normalization: state.normalization.copyWith(enabled: enabled),
      ),
    );
  }
}
