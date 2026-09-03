import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/di/service_locator.dart';
import 'package:jellyfinity/core/logging/logger.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/jellyfin_client_identity.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/jellyfin_server_probe.dart';

void main() {
  group('configureDependencies', () {
    tearDown(() async {
      await getIt.reset();
    });

    test('registers a resolvable Logger', () async {
      await configureDependencies();

      expect(getIt.isRegistered<Logger>(), isTrue);
      expect(getIt<Logger>(), isA<Logger>());
    });

    test('resolves the same lazy singleton on repeated lookups', () async {
      await configureDependencies();

      expect(identical(getIt<Logger>(), getIt<Logger>()), isTrue);
    });

    test('wires the Jellyfin transport layer', () async {
      await configureDependencies();

      expect(getIt<JellyfinClientIdentity>().clientName, 'Jellyfinity');
      expect(getIt<AuthTokenProvider>(), isA<NoAuthTokenProvider>());
      expect(getIt.isRegistered<JellyfinServerProbe>(), isTrue);
      // The probe resolves its whole dependency graph without throwing.
      expect(getIt<JellyfinServerProbe>(), isA<JellyfinServerProbe>());
    });
  });
}
