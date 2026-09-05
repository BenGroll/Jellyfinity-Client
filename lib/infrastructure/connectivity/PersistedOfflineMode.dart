import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../domain/connectivity/OfflineMode.dart';
import '../../domain/downloads/NetworkCondition.dart';
import '../persistence/key_value_store.dart';

/// [OfflineMode] over [NetworkCondition] (the radio) and [KeyValueStore]
/// (the remembered switch) — v0.2.3.
///
/// Both facts are read once at construction and then followed:
/// connectivity from [NetworkCondition.changes], the manual switch from
/// its last written value. Neither read blocks construction — the service
/// starts optimistically online (`isConnected: true`, `isManual: false`)
/// and corrects itself a beat later, the same "resolve after first paint"
/// stance `SessionCubit` and `PlaybackCubit` take with their restores. A
/// currently-offline device still falls back to the local copy through
/// the ordinary cache path even in that first beat.
///
/// The one place `NetworkCondition` is turned into an app-wide offline
/// signal; `OfflineCubit` and the cached repositories sit on top of this
/// and never touch `NetworkCondition` themselves.
@LazySingleton(as: OfflineMode)
class PersistedOfflineMode implements OfflineMode {
  PersistedOfflineMode(this._network, this._store)
    : _status = OfflineStatus.online {
    _networkSub = _network.changes().listen((state) {
      _update(_status.copyWith(isConnected: state != NetworkState.none));
    });
    unawaited(_restore());
  }

  final NetworkCondition _network;
  final KeyValueStore _store;

  static const String _manualKey = 'offline.manual';

  OfflineStatus _status;
  late final StreamSubscription<NetworkState> _networkSub;
  final StreamController<OfflineStatus> _changes =
      StreamController<OfflineStatus>.broadcast();

  @override
  OfflineStatus get status => _status;

  @override
  Stream<OfflineStatus> changes() => _changes.stream;

  @override
  Future<void> setManual(bool value) async {
    if (value == _status.isManual) return;
    await _store.setBool(_manualKey, value);
    _update(_status.copyWith(isManual: value));
  }

  Future<void> _restore() async {
    try {
      final manual = await _store.getBool(_manualKey) ?? false;
      final network = await _network.current();
      _update(
        OfflineStatus(
          isManual: manual,
          isConnected: network != NetworkState.none,
        ),
      );
    } on Object {
      // A probe or store that throws leaves the optimistic seed in place.
    }
  }

  void _update(OfflineStatus next) {
    if (next == _status) return;
    _status = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  /// Not wired as an injectable `@disposeMethod` — the registration is
  /// `as OfflineMode` and the generator would call this on the interface.
  /// The singleton lives for the process; this exists for tests that build
  /// the service directly.
  void dispose() {
    unawaited(_networkSub.cancel());
    unawaited(_changes.close());
  }
}
