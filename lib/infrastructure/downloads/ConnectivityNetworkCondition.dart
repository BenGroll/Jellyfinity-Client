import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';

import '../../domain/downloads/NetworkCondition.dart';

/// [NetworkCondition] over `connectivity_plus` (v0.2.2).
///
/// `connectivity_plus` reports the device's *radio* status, not whether a
/// request would actually succeed — which is all the Wi-Fi-only
/// preference needs, since the download engine still reports a real
/// failure if a connection that looked usable is not. The mapping is
/// deliberately conservative:
///
/// - Wi-Fi and ethernet are [NetworkState.unmetered].
/// - Cellular and satellite are [NetworkState.metered].
/// - No connection is [NetworkState.none].
/// - VPN / bluetooth / other are treated as [NetworkState.metered]: the
///   platform will not say what is underneath a VPN, and charging a
///   download to a connection that might be cellular is the safer default
///   for a preference whose whole point is not to spend mobile data.
///
/// The one place `connectivity_plus` is imported; everything above the
/// [NetworkCondition] seam is unaware of it.
@LazySingleton(as: NetworkCondition)
class ConnectivityNetworkCondition implements NetworkCondition {
  ConnectivityNetworkCondition({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  @factoryMethod
  factory ConnectivityNetworkCondition.create() =>
      ConnectivityNetworkCondition();

  final Connectivity _connectivity;

  @override
  Future<NetworkState> current() async =>
      reduce(await _connectivity.checkConnectivity());

  @override
  Stream<NetworkState> changes() =>
      _connectivity.onConnectivityChanged.map(reduce).distinct();

  /// The device can report several transports at once (`[mobile, vpn]`,
  /// `[wifi, ethernet]`). The best one wins: any unmetered transport
  /// makes the whole connection unmetered; otherwise any real transport
  /// makes it metered; only an empty/`none` list is offline.
  ///
  /// Not private so the mapping — the one non-trivial thing this adapter
  /// does — can be exercised without a platform channel.
  static NetworkState reduce(List<ConnectivityResult> results) {
    var sawMetered = false;
    for (final result in results) {
      switch (result) {
        case ConnectivityResult.wifi:
        case ConnectivityResult.ethernet:
          return NetworkState.unmetered;
        case ConnectivityResult.mobile:
        case ConnectivityResult.satellite:
        case ConnectivityResult.vpn:
        case ConnectivityResult.bluetooth:
        case ConnectivityResult.other:
          sawMetered = true;
        case ConnectivityResult.none:
          break;
      }
    }
    return sawMetered ? NetworkState.metered : NetworkState.none;
  }
}
