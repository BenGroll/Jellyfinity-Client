// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:jellyfinity/app/router/app_router.dart' as _i29;
import 'package:jellyfinity/app/session/auth_session_manager.dart' as _i887;
import 'package:jellyfinity/app/session/session_auth_token_provider.dart'
    as _i318;
import 'package:jellyfinity/app/session/session_cubit.dart' as _i737;
import 'package:jellyfinity/core/logging/console_logger.dart' as _i52;
import 'package:jellyfinity/core/logging/logger.dart' as _i20;
import 'package:jellyfinity/domain/session/account_store.dart' as _i413;
import 'package:jellyfinity/domain/session/credential_store.dart' as _i858;
import 'package:jellyfinity/domain/session/jellyfin_authenticator.dart'
    as _i403;
import 'package:jellyfinity/domain/session/server_registry.dart' as _i607;
import 'package:jellyfinity/domain/session/session.dart' as _i901;
import 'package:jellyfinity/features/auth/presentation/accounts/accounts_cubit.dart'
    as _i322;
import 'package:jellyfinity/features/auth/presentation/login/login_cubit.dart'
    as _i1045;
import 'package:jellyfinity/features/auth/presentation/server_setup/server_setup_cubit.dart'
    as _i952;
import 'package:jellyfinity/infrastructure/jellyfin/auth/dio_jellyfin_authenticator.dart'
    as _i870;
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart'
    as _i430;
import 'package:jellyfinity/infrastructure/jellyfin/identity/jellyfin_client_identity.dart'
    as _i685;
import 'package:jellyfinity/infrastructure/jellyfin/jellyfin_transport_module.dart'
    as _i739;
import 'package:jellyfinity/infrastructure/jellyfin/server/jellyfin_server_probe.dart'
    as _i478;
import 'package:jellyfinity/infrastructure/persistence/file_account_store.dart'
    as _i136;
import 'package:jellyfinity/infrastructure/persistence/file_server_registry.dart'
    as _i160;
import 'package:jellyfinity/infrastructure/persistence/json_store.dart' as _i43;
import 'package:jellyfinity/infrastructure/persistence/persistence_module.dart'
    as _i1069;
import 'package:jellyfinity/infrastructure/secure/secure_credential_store.dart'
    as _i508;
import 'package:jellyfinity/infrastructure/secure/secure_storage_module.dart'
    as _i250;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final jellyfinTransportModule = _$JellyfinTransportModule();
    final secureStorageModule = _$SecureStorageModule();
    final persistenceModule = _$PersistenceModule();
    gh.lazySingleton<_i685.JellyfinClientIdentity>(
      () => jellyfinTransportModule.clientIdentity(),
    );
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => secureStorageModule.secureStorage(),
    );
    gh.lazySingleton<_i20.Logger>(() => _i52.ConsoleLogger());
    gh.lazySingleton<_i858.CredentialStore>(
      () => _i508.SecureCredentialStore(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i403.JellyfinAuthenticator>(
      () => _i870.DioJellyfinAuthenticator(
        gh<_i685.JellyfinClientIdentity>(),
        gh<_i20.Logger>(),
      ),
    );
    gh.lazySingleton<_i43.JsonStore>(
      () => persistenceModule.jsonStore(gh<_i20.Logger>()),
    );
    gh.lazySingleton<_i413.AccountStore>(
      () => _i136.FileAccountStore(gh<_i43.JsonStore>()),
    );
    gh.lazySingleton<_i607.ServerRegistry>(
      () => _i160.FileServerRegistry(gh<_i43.JsonStore>()),
    );
    gh.lazySingleton<_i887.AuthSessionManager>(
      () => _i887.AuthSessionManager(
        gh<_i901.ServerRegistry>(),
        gh<_i901.AccountStore>(),
        gh<_i901.CredentialStore>(),
        gh<_i901.JellyfinAuthenticator>(),
        gh<_i20.Logger>(),
      ),
    );
    gh.lazySingleton<_i430.AuthTokenProvider>(
      () => _i318.SessionAuthTokenProvider(gh<_i887.AuthSessionManager>()),
    );
    gh.lazySingleton<_i737.SessionCubit>(
      () => _i737.SessionCubit(gh<_i887.AuthSessionManager>()),
    );
    gh.lazySingleton<_i478.JellyfinServerProbe>(
      () => _i478.JellyfinServerProbe(
        gh<_i685.JellyfinClientIdentity>(),
        gh<_i430.AuthTokenProvider>(),
        gh<_i20.Logger>(),
      ),
    );
    gh.factory<_i1045.LoginCubit>(
      () => _i1045.LoginCubit(gh<_i737.SessionCubit>()),
    );
    gh.lazySingleton<_i29.AppRouter>(
      () => _i29.AppRouter(gh<_i737.SessionCubit>()),
    );
    gh.factory<_i322.AccountsCubit>(
      () => _i322.AccountsCubit(
        gh<_i607.ServerRegistry>(),
        gh<_i413.AccountStore>(),
        gh<_i737.SessionCubit>(),
      ),
    );
    gh.factory<_i952.ServerSetupCubit>(
      () => _i952.ServerSetupCubit(gh<_i478.JellyfinServerProbe>()),
    );
    return this;
  }
}

class _$JellyfinTransportModule extends _i739.JellyfinTransportModule {}

class _$SecureStorageModule extends _i250.SecureStorageModule {}

class _$PersistenceModule extends _i1069.PersistenceModule {}
