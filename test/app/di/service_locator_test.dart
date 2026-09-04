import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';
import 'package:jellyfinity/infrastructure/persistence/device_identity_store.dart';
import 'package:jellyfinity/infrastructure/persistence/key_value_store.dart';
import 'package:jellyfinity/app/session/AuthSessionManager.dart';
import 'package:jellyfinity/app/session/SessionAuthTokenProvider.dart';
import 'package:jellyfinity/app/session/SessionCubit.dart';
import 'package:jellyfinity/core/logging/Logger.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/domain/session/AccountStore.dart';
import 'package:jellyfinity/domain/session/CredentialStore.dart';
import 'package:jellyfinity/domain/session/JellyfinAuthenticator.dart';
import 'package:jellyfinity/domain/session/ServerRegistry.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/JellyfinClientIdentity.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/JellyfinSessionContext.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/jellyfin_media_api.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/JellyfinServerProbe.dart';
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

    test('wires the media repositories (ADR-0011)', () async {
      await configureDependencies();

      // Feature code resolves the contracts; the Jellyfin-backed
      // implementations behind them stay an infrastructure detail.
      expect(getIt<MusicLibraryRepository>(), isA<MusicLibraryRepository>());
      expect(getIt<PlaylistRepository>(), isA<PlaylistRepository>());
      expect(getIt<MediaMetadataRepository>(), isA<MediaMetadataRepository>());
      expect(
        getIt<PlaybackProgressRepository>(),
        isA<PlaybackProgressRepository>(),
      );
      expect(getIt<ArtworkResolver>(), isA<ArtworkResolver>());
      expect(getIt<JellyfinMediaApi>(), isA<JellyfinMediaApi>());
      // The media layer reads the active profile through the same kind
      // of seam the token provider uses.
      expect(getIt<JellyfinSessionContext>().serverId, isNull);
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
