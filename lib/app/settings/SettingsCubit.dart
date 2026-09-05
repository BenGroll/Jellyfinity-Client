import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/playback/CrossfadeSettings.dart';
import '../../domain/playback/NormalizationSettings.dart';
import '../../domain/playback/stream_quality.dart';
import '../../infrastructure/persistence/key_value_store.dart';
import 'ShellNavigationMode.dart';

/// The instance names the two download preferences resolved in
/// `bootstrap()` are registered under (v0.2.2). `StreamQuality` and
/// `bool` are both already-registered plain types, so the download
/// preferences take a name to sit beside them.
const String initialDownloadQuality = 'settings.initialDownloadQuality';
const String initialDownloadsWifiOnly = 'settings.initialDownloadsWifiOnly';

class SettingsState extends Equatable {
  const SettingsState({
    required this.navigationMode,
    required this.streamQuality,
    required this.downloadQuality,
    required this.downloadsWifiOnly,
    required this.crossfade,
    required this.normalization,
  });

  final ShellNavigationMode navigationMode;
  final StreamQuality streamQuality;

  /// The quality new and retried downloads are fetched at (v0.2.2),
  /// persisted independently of [streamQuality]: a listener can stream
  /// data-saver on the move while still keeping lossless copies, or the
  /// reverse. It never rewrites a file already on the device.
  final StreamQuality downloadQuality;

  /// Whether a download may only run on an unmetered connection (v0.2.2).
  /// Off by default — `ROADMAP.md`'s safe starting point, since it never
  /// silently blocks a requested download.
  final bool downloadsWifiOnly;

  final CrossfadeSettings crossfade;
  final NormalizationSettings normalization;

  SettingsState copyWith({
    ShellNavigationMode? navigationMode,
    StreamQuality? streamQuality,
    StreamQuality? downloadQuality,
    bool? downloadsWifiOnly,
    CrossfadeSettings? crossfade,
    NormalizationSettings? normalization,
  }) => SettingsState(
    navigationMode: navigationMode ?? this.navigationMode,
    streamQuality: streamQuality ?? this.streamQuality,
    downloadQuality: downloadQuality ?? this.downloadQuality,
    downloadsWifiOnly: downloadsWifiOnly ?? this.downloadsWifiOnly,
    crossfade: crossfade ?? this.crossfade,
    normalization: normalization ?? this.normalization,
  );

  @override
  List<Object?> get props => [
    navigationMode,
    streamQuality,
    downloadQuality,
    downloadsWifiOnly,
    crossfade,
    normalization,
  ];
}

/// The app's persisted preferences — [ShellNavigationMode],
/// [StreamQuality], the download quality and Wi-Fi-only policy (v0.2.2),
/// [CrossfadeSettings] and [NormalizationSettings] — with room to grow
/// the same way `AppConfig`/`KeyValueStore` already do.
///
/// Every initial value is resolved once in `bootstrap()`, right after
/// `configureDependencies()` returns, so the very first frame already
/// renders/plays at the saved settings — no flash of the default followed
/// by a swap, unlike `SessionCubit`/`PlaybackCubit`'s unawaited restores,
/// which are fine to resolve after first paint.
///
/// A [lazySingleton], not a factory: it is app-wide state that
/// `PlaybackCubit` and `DownloadsCubit` both read and listen to, and
/// those must see the same instance the settings screen writes to.
@lazySingleton
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(
    this._store,
    ShellNavigationMode initialNavigationMode,
    StreamQuality initialStreamQuality,
    @Named(initialDownloadQuality) StreamQuality startingDownloadQuality,
    @Named(initialDownloadsWifiOnly) bool startingDownloadsWifiOnly,
    CrossfadeSettings initialCrossfade,
    NormalizationSettings initialNormalization,
  ) : super(
        SettingsState(
          navigationMode: initialNavigationMode,
          streamQuality: initialStreamQuality,
          downloadQuality: startingDownloadQuality,
          downloadsWifiOnly: startingDownloadsWifiOnly,
          crossfade: initialCrossfade,
          normalization: initialNormalization,
        ),
      );

  final KeyValueStore _store;

  static const _navigationModeKey = 'settings.navigationMode';
  static const _streamQualityKey = 'settings.streamQuality';
  static const _downloadQualityKey = 'settings.downloadQuality';
  static const _downloadsWifiOnlyKey = 'settings.downloadsWifiOnly';
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

  /// Reads the download-quality preference (v0.2.2). A missing value
  /// degrades to [StreamQuality.original] — `ROADMAP.md`'s intended safe
  /// starting point, because it never silently changes what a user gets.
  static Future<StreamQuality> loadInitialDownloadQuality(
    KeyValueStore store,
  ) async {
    final raw = await store.getString(_downloadQualityKey);
    return StreamQuality.tryParse(raw) ?? StreamQuality.original;
  }

  /// Reads the Wi-Fi-only download preference (v0.2.2). Missing means
  /// off, the safe default: an opt-in that never blocks a requested
  /// download until the user asks it to.
  static Future<bool> loadInitialDownloadsWifiOnly(KeyValueStore store) async {
    return await store.getBool(_downloadsWifiOnlyKey) ?? false;
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

  /// Sets the download quality. Takes effect for downloads requested or
  /// retried after this point; files already on the device are left as
  /// they are (v0.2.2).
  Future<void> setDownloadQuality(StreamQuality quality) async {
    if (quality == state.downloadQuality) return;
    await _store.setString(_downloadQualityKey, quality.name);
    emit(state.copyWith(downloadQuality: quality));
  }

  Future<void> setDownloadsWifiOnly(bool wifiOnly) async {
    if (wifiOnly == state.downloadsWifiOnly) return;
    await _store.setBool(_downloadsWifiOnlyKey, wifiOnly);
    emit(state.copyWith(downloadsWifiOnly: wifiOnly));
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
