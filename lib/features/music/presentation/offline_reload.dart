import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/connectivity/OfflineMode.dart';

/// Makes a music cubit re-read itself when the app crosses between online
/// and offline (v0.2.3).
///
/// Switching "Work offline" on or off, or a connection coming or going,
/// changes what every library read answers with — the server's live list,
/// or the saved copy / downloads. Without this, a screen already on
/// screen keeps whatever it loaded under the old mode until the user
/// navigates away and back. `bindOfflineReload` wires the cubit to
/// `OfflineMode.changes` and calls [onOfflineChanged] exactly on the
/// transitions that matter (not on every connectivity blip that does not
/// flip `isOffline`).
mixin OfflineReload<S> on Cubit<S> {
  StreamSubscription<OfflineStatus>? _offlineSub;
  bool _wasOffline = false;

  /// Call once from the constructor. A `null` [offlineMode] — the way a
  /// test builds the cubit without wiring connectivity — simply does
  /// nothing.
  void bindOfflineReload(OfflineMode? offlineMode) {
    if (offlineMode == null) return;
    _wasOffline = offlineMode.status.isOffline;
    _offlineSub = offlineMode.changes().listen((status) {
      if (isClosed || status.isOffline == _wasOffline) return;
      _wasOffline = status.isOffline;
      onOfflineChanged();
    });
  }

  /// Re-read whatever this cubit is showing. Implementations typically
  /// call `reload()` / `retry()` — but only when there is already
  /// something on screen, so an unopened tab is not forced to load.
  void onOfflineChanged();

  @override
  Future<void> close() {
    _offlineSub?.cancel();
    return super.close();
  }
}
