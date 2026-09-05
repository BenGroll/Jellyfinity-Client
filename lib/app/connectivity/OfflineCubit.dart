import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/connectivity/OfflineMode.dart';

/// The app-wide view of Jellyfinity's offline state (v0.2.3).
///
/// A thin `Cubit` over the [OfflineMode] seam so widgets — the sidebar
/// switch, the offline banner on search, the library's "Limited" scope —
/// can `watch` it the same way they watch `SessionCubit` or
/// `DownloadsCubit`. It holds no rules of its own: [OfflineMode] is the
/// source of truth, this just makes its stream a bloc.
///
/// A [lazySingleton] at [JellyfinityApp] level, like the other
/// cross-cutting cubits: the shell, the library and search all read the
/// same instance.
@lazySingleton
class OfflineCubit extends Cubit<OfflineStatus> {
  OfflineCubit(this._mode) : super(_mode.status) {
    _sub = _mode.changes().listen(emit);
  }

  final OfflineMode _mode;
  late final StreamSubscription<OfflineStatus> _sub;

  /// Flips the "Go offline" switch. No-op while there is no connection —
  /// the app is already offline and the switch is shown disabled.
  Future<void> setManualOffline(bool value) => _mode.setManual(value);

  @override
  Future<void> close() {
    unawaited(_sub.cancel());
    return super.close();
  }
}
