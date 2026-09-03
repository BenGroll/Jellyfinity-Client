// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:jellyfinity/app/router/app_router.dart' as _i29;
import 'package:jellyfinity/app/session/session_cubit.dart' as _i737;
import 'package:jellyfinity/core/logging/console_logger.dart' as _i52;
import 'package:jellyfinity/core/logging/logger.dart' as _i20;
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart'
    as _i430;
import 'package:jellyfinity/infrastructure/jellyfin/identity/jellyfin_client_identity.dart'
    as _i685;
import 'package:jellyfinity/infrastructure/jellyfin/jellyfin_transport_module.dart'
    as _i739;
import 'package:jellyfinity/infrastructure/jellyfin/server/jellyfin_server_probe.dart'
    as _i478;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final jellyfinTransportModule = _$JellyfinTransportModule();
    gh.lazySingleton<_i737.SessionCubit>(() => _i737.SessionCubit());
    gh.lazySingleton<_i685.JellyfinClientIdentity>(
      () => jellyfinTransportModule.clientIdentity(),
    );
    gh.lazySingleton<_i29.AppRouter>(
      () => _i29.AppRouter(gh<_i737.SessionCubit>()),
    );
    gh.lazySingleton<_i20.Logger>(() => _i52.ConsoleLogger());
    gh.lazySingleton<_i430.AuthTokenProvider>(
      () => const _i430.NoAuthTokenProvider(),
    );
    gh.lazySingleton<_i478.JellyfinServerProbe>(
      () => _i478.JellyfinServerProbe(
        gh<_i685.JellyfinClientIdentity>(),
        gh<_i430.AuthTokenProvider>(),
        gh<_i20.Logger>(),
      ),
    );
    return this;
  }
}

class _$JellyfinTransportModule extends _i739.JellyfinTransportModule {}
