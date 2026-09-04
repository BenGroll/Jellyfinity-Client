import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/playback/stream_quality.dart';
import '../../infrastructure/persistence/key_value_store.dart';
import 'ShellNavigationMode.dart';

class SettingsState extends Equatable {
  const SettingsState({
    required this.navigationMode,
    required this.streamQuality,
  });

  final ShellNavigationMode navigationMode;
  final StreamQuality streamQuality;

  @override
  List<Object?> get props => [navigationMode, streamQuality];
}

/// The app's persisted preferences — [ShellNavigationMode] and
/// [StreamQuality] today, with room to grow the same way
/// `AppConfig`/`KeyValueStore` already do.
///
/// Both initial values are resolved once in `bootstrap()`, right after
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
  ) : super(
        SettingsState(
          navigationMode: initialNavigationMode,
          streamQuality: initialStreamQuality,
        ),
      );

  final KeyValueStore _store;

  static const _navigationModeKey = 'settings.navigationMode';
  static const _streamQualityKey = 'settings.streamQuality';

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

  Future<void> setNavigationMode(ShellNavigationMode mode) async {
    if (mode == state.navigationMode) return;
    await _store.setString(_navigationModeKey, mode.name);
    emit(
      SettingsState(navigationMode: mode, streamQuality: state.streamQuality),
    );
  }

  Future<void> setStreamQuality(StreamQuality quality) async {
    if (quality == state.streamQuality) return;
    await _store.setString(_streamQualityKey, quality.name);
    emit(
      SettingsState(
        navigationMode: state.navigationMode,
        streamQuality: quality,
      ),
    );
  }
}
