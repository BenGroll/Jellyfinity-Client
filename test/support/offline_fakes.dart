import 'dart:async';

import 'package:jellyfinity/app/connectivity/OfflineCubit.dart';
import 'package:jellyfinity/domain/connectivity/OfflineMode.dart';

/// An [OfflineMode] whose state a test sets directly — no `NetworkCondition`
/// and no `KeyValueStore` (v0.2.3).
class FakeOfflineMode implements OfflineMode {
  FakeOfflineMode({bool manual = false, bool connected = true})
    : _status = OfflineStatus(isManual: manual, isConnected: connected);

  OfflineStatus _status;
  final StreamController<OfflineStatus> _changes =
      StreamController<OfflineStatus>.broadcast();

  @override
  OfflineStatus get status => _status;

  @override
  Stream<OfflineStatus> changes() => _changes.stream;

  @override
  Future<void> setManual(bool value) async {
    _emit(_status.copyWith(isManual: value));
  }

  /// Simulate the connection coming or going.
  void setConnected(bool value) => _emit(_status.copyWith(isConnected: value));

  void _emit(OfflineStatus next) {
    if (next == _status) return;
    _status = next;
    _changes.add(next);
  }

  Future<void> dispose() => _changes.close();
}

/// An [OfflineCubit] over a [FakeOfflineMode], for widget tests where the
/// sidebar, library or search read the offline state.
OfflineCubit fakeOfflineCubit({bool manual = false, bool connected = true}) =>
    OfflineCubit(FakeOfflineMode(manual: manual, connected: connected));
