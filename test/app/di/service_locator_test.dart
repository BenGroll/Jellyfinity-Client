import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/persistence/database/app_database.dart';
import 'package:jellyfinity/infrastructure/persistence/device_identity_store.dart';
import 'package:jellyfinity/infrastructure/persistence/key_value_store.dart';
import 'package:jellyfinity/app/session/auth_session_manager.dart';
import 'package:jellyfinity/app/session/session_auth_token_provider.dart';
import 'package:jellyfinity/app/session/session_cubit.dart';
import 'package:jellyfinity/core/logging/logger.dart';
import 'package:jellyfinity/domain/session/account_store.dart';
import 'package:jellyfinity/domain/session/credential_store.dart';
import 'package:jellyfinity/domain/session/jellyfin_authenticator.dart';
import 'package:jellyfinity/domain/session/server_registry.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/jellyfin_client_identity.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/jellyfin_server_probe.dart';
import 'package:jellyfinity/app/di/service_locator.dart';

import '../../support/fake_path_provider.dart';

void main() {
  group('configureDependencies', () {
    setUp(useFakePathProvider);

    tearDown(() async {
      if (getIt.isRegistered<AppDatabase>()) {
        await getIt<AppDatabase>().close();
      }
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
      expect(getIt.isRegistered<JellyfinServerProbe>(), isTrue);
      // The probe resolves its whole dependency graph without throwing.
      expect(getIt<JellyfinServerProbe>(), isA<JellyfinServerProbe>());
    });

    test('wires the v0.0.5 session graph', () async {
      await configureDependencies();

      // The real token provider replaced NoAuthTokenProvider.
      expect(getIt<AuthTokenProvider>(), isA<SessionAuthTokenProvider>());
      expect(getIt<ServerRegistry>(), isA<ServerRegistry>());
      expect(getIt<AccountStore>(), isA<AccountStore>());
      expect(getIt<CredentialStore>(), isA<CredentialStore>());
      expect(getIt<JellyfinAuthenticator>(), isA<JellyfinAuthenticator>());
      expect(getIt<AuthSessionManager>(), isA<AuthSessionManager>());
      expect(getIt<SessionCubit>(), isA<SessionCubit>());
    });

    test('wires the local database and its stores (ADR-0010)', () async {
      await configureDependencies();

      expect(getIt<AppDatabase>(), isA<AppDatabase>());
      expect(getIt<KeyValueStore>(), isA<KeyValueStore>());
      expect(getIt<DeviceIdentityStore>(), isA<DeviceIdentityStore>());
      // The persisted device id flows into the client identity.
      final deviceId = await getIt<DeviceIdentityStore>().deviceId();
      expect(getIt<JellyfinClientIdentity>().deviceId, deviceId);
    });
  });
}
