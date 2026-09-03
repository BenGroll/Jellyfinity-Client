import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/jellyfin_client_identity.dart';

void main() {
  const identity = JellyfinClientIdentity(
    clientName: 'Jellyfinity',
    clientVersion: '0.0.4',
    deviceName: 'Test Device',
    deviceId: 'abc123',
  );

  group('authorizationHeaderValue', () {
    test('emits the MediaBrowser scheme with all identity fields', () {
      final header = identity.authorizationHeaderValue();

      expect(header, startsWith('MediaBrowser '));
      expect(header, contains('Client="Jellyfinity"'));
      expect(header, contains('Version="0.0.4"'));
      expect(header, contains('DeviceId="abc123"'));
      expect(header, contains('Device="Test Device"'));
    });

    test('omits the token when unauthenticated', () {
      expect(identity.authorizationHeaderValue(), isNot(contains('Token=')));
      expect(
        identity.authorizationHeaderValue(token: ''),
        isNot(contains('Token=')),
      );
    });

    test('includes the token when provided', () {
      expect(
        identity.authorizationHeaderValue(token: 'secret-token'),
        contains('Token="secret-token"'),
      );
    });

    test('escapes quotes in a field value', () {
      const quirky = JellyfinClientIdentity(
        clientName: 'Jellyfinity',
        clientVersion: '0.0.4',
        deviceName: 'Living Room "TV"',
        deviceId: 'x',
      );
      expect(
        quirky.authorizationHeaderValue(),
        contains(r'Device="Living Room \"TV\""'),
      );
    });
  });

  group('forThisApp', () {
    test('fills in the app name and version', () {
      final identity = JellyfinClientIdentity.forThisApp(deviceId: 'device-1');
      expect(identity.clientName, kJellyfinityClientName);
      expect(identity.clientVersion, kJellyfinityClientVersion);
      expect(identity.deviceId, 'device-1');
    });
  });
}
