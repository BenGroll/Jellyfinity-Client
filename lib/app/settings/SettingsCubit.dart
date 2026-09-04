import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../infrastructure/persistence/key_value_store.dart';
import 'ShellNavigationMode.dart';

class SettingsState extends Equatable {
  const SettingsState({required this.navigationMode});

  final ShellNavigationMode navigationMode;

  @override
  List<Object?> get props => [navigationMode];
}

/// The app's persisted preferences — currently just [ShellNavigationMode],
/// with room to grow the same way `AppConfig`/`KeyValueStore` already do.
///
/// The initial value is resolved once in `bootstrap()`, right after
/// `configureDependencies()` returns, so the very first frame already
/// renders in the saved mode — no flash of the default followed by a
/// swap, unlike `SessionCubit`/`PlaybackCubit`'s unawaited restores, which
/// are fine to resolve after first paint.
@injectable
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._store, ShellNavigationMode initial)
    : super(SettingsState(navigationMode: initial));

  final KeyValueStore _store;

  static const _navigationModeKey = 'settings.navigationMode';

  static Future<ShellNavigationMode> loadInitialNavigationMode(
    KeyValueStore store,
  ) async {
    final raw = await store.getString(_navigationModeKey);
    return ShellNavigationMode.tryParse(raw) ?? ShellNavigationMode.fallback;
  }

  Future<void> setNavigationMode(ShellNavigationMode mode) async {
    if (mode == state.navigationMode) return;
    await _store.setString(_navigationModeKey, mode.name);
    emit(SettingsState(navigationMode: mode));
  }
}
