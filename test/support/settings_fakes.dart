import 'package:jellyfinity/app/navigation/MediaScopeCubit.dart';
import 'package:jellyfinity/app/settings/SettingsCubit.dart';
import 'package:jellyfinity/app/settings/ShellNavigationMode.dart';
import 'package:jellyfinity/domain/playback/CrossfadeSettings.dart';
import 'package:jellyfinity/domain/playback/NormalizationSettings.dart';
import 'package:jellyfinity/domain/playback/stream_quality.dart';
import 'package:jellyfinity/infrastructure/persistence/key_value_store.dart';

/// An in-memory [KeyValueStore], for tests that need `SettingsCubit`'s
/// persistence without a real database.
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<bool?> getBool(String key) async {
    final raw = _values[key];
    return raw == null ? null : raw == 'true';
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = '$value';
  }

  @override
  Future<int?> getInt(String key) async {
    final raw = _values[key];
    return raw == null ? null : int.tryParse(raw);
  }

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = '$value';
  }

  @override
  Future<double?> getDouble(String key) async {
    final raw = _values[key];
    return raw == null ? null : double.tryParse(raw);
  }

  @override
  Future<void> setDouble(String key, double value) async {
    _values[key] = '$value';
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

/// A [SettingsCubit] backed by an in-memory store, for widget tests that
/// only need one to exist (the shared header/sidebar read it from every
/// tab) without exercising real persistence.
SettingsCubit fakeSettingsCubit({
  ShellNavigationMode mode = ShellNavigationMode.mediaPills,
  StreamQuality quality = StreamQuality.original,
  CrossfadeSettings crossfade = CrossfadeSettings.disabled,
  NormalizationSettings normalization = NormalizationSettings.disabled,
}) => SettingsCubit(
  InMemoryKeyValueStore(),
  mode,
  quality,
  crossfade,
  normalization,
);

/// A [MediaScopeCubit] with its default seeded state (Music only).
MediaScopeCubit fakeMediaScopeCubit() => MediaScopeCubit();
