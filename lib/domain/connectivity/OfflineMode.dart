import 'package:equatable/equatable.dart';

/// Whether Jellyfinity is working offline right now, and why (v0.2.3).
///
/// Two independent facts, folded into one [isOffline]:
///
/// - [isManual] — the user flipped the "Go offline" switch. A deliberate
///   choice that holds even on a perfectly good connection: it stops the
///   app spending data, and (with the "Limited" library scope) narrows
///   the library to what is on the device.
/// - [isConnected] — the device has a usable network, as
///   `NetworkCondition` reports it. `false` forces offline regardless of
///   the switch.
class OfflineStatus extends Equatable {
  const OfflineStatus({required this.isManual, required this.isConnected});

  /// The starting point before connectivity has been probed or the saved
  /// preference read: assume online, the same optimistic default the
  /// cache-fallback repositories already take.
  static const OfflineStatus online = OfflineStatus(
    isManual: false,
    isConnected: true,
  );

  /// The user chose to work offline.
  final bool isManual;

  /// The device has a usable connection.
  final bool isConnected;

  /// Whether reads should skip the server and answer from the local copy.
  bool get isOffline => isManual || !isConnected;

  /// Offline purely because there is no connection — the switch is off but
  /// it could not be honoured any other way. The sidebar shows the switch
  /// on and disabled in this state.
  bool get isForcedByConnection => !isConnected;

  OfflineStatus copyWith({bool? isManual, bool? isConnected}) => OfflineStatus(
    isManual: isManual ?? this.isManual,
    isConnected: isConnected ?? this.isConnected,
  );

  @override
  List<Object?> get props => [isManual, isConnected];
}

/// The seam the media layer reads Jellyfinity's offline state through
/// (v0.2.3).
///
/// A domain contract with a `NetworkCondition`- and `KeyValueStore`-backed
/// implementation in `lib/infrastructure/connectivity/`, the same shape as
/// every other seam here: the implementation owns *observation and
/// persistence* (probe the radio, remember the switch), while
/// `OfflineCubit` and the cached repositories own the *policy* (what
/// offline means for a read, what the UI shows).
///
/// `CONTEXT.md` used to say "offline is an item's availability state, not
/// a separate app mode". v0.2.3 deliberately revisits that: a user on a
/// plane wants one switch, not per-item guesswork. Downloaded media is
/// still first-class local media, not disposable cache — that half of the
/// invariant stands. See ADR-0023.
abstract class OfflineMode {
  /// The current state.
  OfflineStatus get status;

  /// Fires whenever [status] changes — the switch flipped, or the
  /// connection came or went.
  Stream<OfflineStatus> changes();

  /// Sets the manual "Go offline" switch and remembers it across runs.
  Future<void> setManual(bool value);
}
