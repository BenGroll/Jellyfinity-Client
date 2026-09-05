import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/downloads/NetworkCondition.dart';
import 'package:jellyfinity/infrastructure/downloads/ConnectivityNetworkCondition.dart';

void main() {
  group('NetworkState.allowsDownload', () {
    test('with Wi-Fi-only off, anything but "no connection" is fine', () {
      expect(NetworkState.unmetered.allowsDownload(wifiOnly: false), isTrue);
      expect(NetworkState.metered.allowsDownload(wifiOnly: false), isTrue);
      expect(NetworkState.none.allowsDownload(wifiOnly: false), isFalse);
    });

    test('with Wi-Fi-only on, only an unmetered connection qualifies', () {
      expect(NetworkState.unmetered.allowsDownload(wifiOnly: true), isTrue);
      expect(NetworkState.metered.allowsDownload(wifiOnly: true), isFalse);
      expect(NetworkState.none.allowsDownload(wifiOnly: true), isFalse);
    });
  });

  group('ConnectivityNetworkCondition.reduce', () {
    test('Wi-Fi or ethernet is unmetered', () {
      expect(
        ConnectivityNetworkCondition.reduce([ConnectivityResult.wifi]),
        NetworkState.unmetered,
      );
      expect(
        ConnectivityNetworkCondition.reduce([
          ConnectivityResult.mobile,
          ConnectivityResult.wifi,
        ]),
        NetworkState.unmetered,
      );
    });

    test('cellular, VPN and unknown transports are treated as metered', () {
      expect(
        ConnectivityNetworkCondition.reduce([ConnectivityResult.mobile]),
        NetworkState.metered,
      );
      expect(
        ConnectivityNetworkCondition.reduce([ConnectivityResult.vpn]),
        NetworkState.metered,
      );
    });

    test('an empty or none-only list is offline', () {
      expect(ConnectivityNetworkCondition.reduce([]), NetworkState.none);
      expect(
        ConnectivityNetworkCondition.reduce([ConnectivityResult.none]),
        NetworkState.none,
      );
    });
  });
}
