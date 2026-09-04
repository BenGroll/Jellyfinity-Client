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
import 'package:jellyfinity/app/navigation/MediaScopeCubit.dart' as _i84;
import 'package:jellyfinity/app/playback/PlaybackCubit.dart' as _i126;
import 'package:jellyfinity/app/router/AppRouter.dart' as _i587;
import 'package:jellyfinity/app/session/AuthSessionManager.dart' as _i56;
import 'package:jellyfinity/app/session/SessionAuthTokenProvider.dart' as _i51;
import 'package:jellyfinity/app/session/SessionCubit.dart' as _i809;
import 'package:jellyfinity/app/session/SessionJellyfinContext.dart' as _i139;
import 'package:jellyfinity/app/settings/SettingsCubit.dart' as _i230;
import 'package:jellyfinity/app/settings/ShellNavigationMode.dart' as _i883;
import 'package:jellyfinity/core/logging/ConsoleLogger.dart' as _i1033;
import 'package:jellyfinity/core/logging/Logger.dart' as _i612;
import 'package:jellyfinity/domain/media/ArtworkResolver.dart' as _i285;
import 'package:jellyfinity/domain/media/media.dart' as _i747;
import 'package:jellyfinity/domain/media/PlaybackProgressRepository.dart'
    as _i474;
import 'package:jellyfinity/domain/playback/AudioSourceResolver.dart' as _i922;
import 'package:jellyfinity/domain/playback/PlaybackEngine.dart' as _i717;
import 'package:jellyfinity/domain/playback/QueueRepository.dart' as _i642;
import 'package:jellyfinity/domain/playback/stream_quality.dart' as _i731;
import 'package:jellyfinity/domain/playback/TrackSourceInfoResolver.dart'
    as _i621;
import 'package:jellyfinity/domain/session/AccountStore.dart' as _i756;
import 'package:jellyfinity/domain/session/CredentialStore.dart' as _i866;
import 'package:jellyfinity/domain/session/JellyfinAuthenticator.dart' as _i534;
import 'package:jellyfinity/domain/session/ServerRegistry.dart' as _i848;
import 'package:jellyfinity/domain/session/session.dart' as _i901;
import 'package:jellyfinity/features/auth/presentation/accounts/accounts_cubit.dart'
    as _i322;
import 'package:jellyfinity/features/auth/presentation/login/login_cubit.dart'
    as _i1045;
import 'package:jellyfinity/features/auth/presentation/server_setup/server_setup_cubit.dart'
    as _i952;
import 'package:jellyfinity/features/music/presentation/detail/media_detail_cubit.dart'
    as _i213;
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart'
    as _i618;
import 'package:jellyfinity/features/music/presentation/search/music_search_cubit.dart'
    as _i169;
import 'package:jellyfinity/features/playback/presentation/track_source_info_cubit.dart'
    as _i766;
import 'package:jellyfinity/infrastructure/jellyfin/auth/DioJellyfinAuthenticator.dart'
    as _i833;
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart'
    as _i430;
import 'package:jellyfinity/infrastructure/jellyfin/identity/JellyfinClientIdentity.dart'
    as _i787;
import 'package:jellyfinity/infrastructure/jellyfin/identity/JellyfinSessionContext.dart'
    as _i346;
import 'package:jellyfinity/infrastructure/jellyfin/JellyfinTransportModule.dart'
    as _i748;
import 'package:jellyfinity/infrastructure/jellyfin/media/jellyfin_media_api.dart'
    as _i963;
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinArtworkResolver.dart'
    as _i1022;
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinAudioSourceResolver.dart'
    as _i860;
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinMediaMetadataRepository.dart'
    as _i830;
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinMusicLibraryRepository.dart'
    as _i814;
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinPlaybackProgressRepository.dart'
    as _i36;
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinPlaylistRepository.dart'
    as _i516;
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinTrackSourceInfoResolver.dart'
    as _i89;
import 'package:jellyfinity/infrastructure/jellyfin/server/JellyfinServerProbe.dart'
    as _i906;
import 'package:jellyfinity/infrastructure/media/CachedMediaMetadataRepository.dart'
    as _i912;
import 'package:jellyfinity/infrastructure/media/CachedMusicLibraryRepository.dart'
    as _i664;
import 'package:jellyfinity/infrastructure/media/CachedPlaylistRepository.dart'
    as _i246;
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart'
    as _i242;
import 'package:jellyfinity/infrastructure/persistence/DatabaseModule.dart'
    as _i923;
import 'package:jellyfinity/infrastructure/persistence/device_identity_store.dart'
    as _i584;
import 'package:jellyfinity/infrastructure/persistence/DriftAccountStore.dart'
    as _i243;
import 'package:jellyfinity/infrastructure/persistence/DriftServerRegistry.dart'
    as _i776;
import 'package:jellyfinity/infrastructure/persistence/key_value_store.dart'
    as _i617;
import 'package:jellyfinity/infrastructure/persistence/LegacyJsonImporter.dart'
    as _i408;
import 'package:jellyfinity/infrastructure/persistence/media/media_cache_store.dart'
    as _i1018;
import 'package:jellyfinity/infrastructure/persistence/playback/DriftQueueRepository.dart'
    as _i24;
import 'package:jellyfinity/infrastructure/secure/SecureCredentialStore.dart'
    as _i834;
import 'package:jellyfinity/infrastructure/secure/SecureStorageModule.dart'
    as _i318;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final databaseModule = _$DatabaseModule();
    final secureStorageModule = _$SecureStorageModule();
    final jellyfinTransportModule = _$JellyfinTransportModule();
    gh.factory<_i84.MediaScopeCubit>(() => _i84.MediaScopeCubit());
    gh.lazySingleton<_i242.AppDatabase>(() => databaseModule.appDatabase());
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => secureStorageModule.secureStorage(),
    );
    gh.lazySingleton<_i612.Logger>(() => _i1033.ConsoleLogger());
    gh.lazySingleton<_i866.CredentialStore>(
      () => _i834.SecureCredentialStore(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i848.ServerRegistry>(
      () => _i776.DriftServerRegistry(gh<_i242.AppDatabase>()),
    );
    gh.lazySingleton<_i1018.MediaCacheStore>(
      () => _i1018.DriftMediaCacheStore(gh<_i242.AppDatabase>()),
    );
    gh.lazySingleton<_i617.KeyValueStore>(
      () => _i617.DriftKeyValueStore(gh<_i242.AppDatabase>()),
    );
    gh.lazySingleton<_i584.DeviceIdentityStore>(
      () => _i584.PersistentDeviceIdentityStore(gh<_i617.KeyValueStore>()),
    );
    gh.lazySingleton<_i408.LegacyJsonImporter>(
      () => _i408.LegacyJsonImporter(
        gh<_i242.AppDatabase>(),
        gh<_i617.KeyValueStore>(),
        gh<_i612.Logger>(),
      ),
    );
    await gh.lazySingletonAsync<_i787.JellyfinClientIdentity>(
      () => jellyfinTransportModule.clientIdentity(
        gh<_i584.DeviceIdentityStore>(),
      ),
      preResolve: true,
    );
    gh.factory<_i230.SettingsCubit>(
      () => _i230.SettingsCubit(
        gh<_i617.KeyValueStore>(),
        gh<_i883.ShellNavigationMode>(),
        gh<_i731.StreamQuality>(),
      ),
    );
    gh.lazySingleton<_i756.AccountStore>(
      () => _i243.DriftAccountStore(
        gh<_i242.AppDatabase>(),
        gh<_i617.KeyValueStore>(),
      ),
    );
    gh.lazySingleton<_i534.JellyfinAuthenticator>(
      () => _i833.DioJellyfinAuthenticator(
        gh<_i787.JellyfinClientIdentity>(),
        gh<_i612.Logger>(),
      ),
    );
    gh.lazySingleton<_i642.QueueRepository>(
      () => _i24.DriftQueueRepository(
        gh<_i242.AppDatabase>(),
        gh<_i617.KeyValueStore>(),
      ),
    );
    gh.lazySingleton<_i56.AuthSessionManager>(
      () => _i56.AuthSessionManager(
        gh<_i901.ServerRegistry>(),
        gh<_i901.AccountStore>(),
        gh<_i901.CredentialStore>(),
        gh<_i901.JellyfinAuthenticator>(),
        gh<_i1018.MediaCacheStore>(),
        gh<_i612.Logger>(),
      ),
    );
    gh.lazySingleton<_i430.AuthTokenProvider>(
      () => _i51.SessionAuthTokenProvider(gh<_i56.AuthSessionManager>()),
    );
    gh.lazySingleton<_i906.JellyfinServerProbe>(
      () => _i906.JellyfinServerProbe(
        gh<_i787.JellyfinClientIdentity>(),
        gh<_i430.AuthTokenProvider>(),
        gh<_i612.Logger>(),
      ),
    );
    gh.lazySingleton<_i346.JellyfinSessionContext>(
      () => _i139.SessionJellyfinContext(gh<_i56.AuthSessionManager>()),
    );
    gh.lazySingleton<_i809.SessionCubit>(
      () => _i809.SessionCubit(gh<_i56.AuthSessionManager>()),
    );
    gh.lazySingleton<_i922.AudioSourceResolver>(
      () => _i860.JellyfinAudioSourceResolver(
        gh<_i346.JellyfinSessionContext>(),
        gh<_i430.AuthTokenProvider>(),
      ),
    );
    gh.lazySingleton<_i285.ArtworkResolver>(
      () => _i1022.JellyfinArtworkResolver(gh<_i346.JellyfinSessionContext>()),
    );
    gh.lazySingleton<_i963.JellyfinMediaApi>(
      () => _i963.JellyfinMediaApi(
        gh<_i346.JellyfinSessionContext>(),
        gh<_i787.JellyfinClientIdentity>(),
        gh<_i430.AuthTokenProvider>(),
        gh<_i612.Logger>(),
      ),
    );
    gh.factory<_i1045.LoginCubit>(
      () => _i1045.LoginCubit(gh<_i809.SessionCubit>()),
    );
    gh.lazySingleton<_i587.AppRouter>(
      () => _i587.AppRouter(gh<_i809.SessionCubit>()),
    );
    gh.factory<_i952.ServerSetupCubit>(
      () => _i952.ServerSetupCubit(gh<_i906.JellyfinServerProbe>()),
    );
    gh.lazySingleton<_i830.JellyfinMediaMetadataRepository>(
      () => _i830.JellyfinMediaMetadataRepository(gh<_i963.JellyfinMediaApi>()),
    );
    gh.lazySingleton<_i814.JellyfinMusicLibraryRepository>(
      () => _i814.JellyfinMusicLibraryRepository(gh<_i963.JellyfinMediaApi>()),
    );
    gh.lazySingleton<_i516.JellyfinPlaylistRepository>(
      () => _i516.JellyfinPlaylistRepository(gh<_i963.JellyfinMediaApi>()),
    );
    gh.factory<_i322.AccountsCubit>(
      () => _i322.AccountsCubit(
        gh<_i848.ServerRegistry>(),
        gh<_i756.AccountStore>(),
        gh<_i809.SessionCubit>(),
      ),
    );
    gh.lazySingleton<_i747.PlaylistRepository>(
      () => _i246.CachedPlaylistRepository(
        gh<_i516.JellyfinPlaylistRepository>(),
        gh<_i1018.MediaCacheStore>(),
        gh<_i346.JellyfinSessionContext>(),
      ),
    );
    gh.lazySingleton<_i747.PlaybackProgressRepository>(
      () =>
          _i36.JellyfinPlaybackProgressRepository(gh<_i963.JellyfinMediaApi>()),
    );
    gh.lazySingleton<_i621.TrackSourceInfoResolver>(
      () => _i89.JellyfinTrackSourceInfoResolver(gh<_i963.JellyfinMediaApi>()),
    );
    gh.lazySingleton<_i126.PlaybackCubit>(
      () => _i126.PlaybackCubit(
        gh<_i717.PlaybackEngine>(),
        gh<_i642.QueueRepository>(),
        gh<_i922.AudioSourceResolver>(),
        gh<_i474.PlaybackProgressRepository>(),
        gh<_i230.SettingsCubit>(),
      ),
    );
    gh.lazySingleton<_i747.MediaMetadataRepository>(
      () => _i912.CachedMediaMetadataRepository(
        gh<_i830.JellyfinMediaMetadataRepository>(),
        gh<_i1018.MediaCacheStore>(),
      ),
    );
    gh.factory<_i618.PlaylistsCubit>(
      () => _i618.PlaylistsCubit(gh<_i747.PlaylistRepository>()),
    );
    gh.factory<_i618.PlaylistTracksCubit>(
      () => _i618.PlaylistTracksCubit(gh<_i747.PlaylistRepository>()),
    );
    gh.factory<_i766.TrackSourceInfoCubit>(
      () => _i766.TrackSourceInfoCubit(gh<_i621.TrackSourceInfoResolver>()),
    );
    gh.lazySingleton<_i747.MusicLibraryRepository>(
      () => _i664.CachedMusicLibraryRepository(
        gh<_i814.JellyfinMusicLibraryRepository>(),
        gh<_i1018.MediaCacheStore>(),
        gh<_i346.JellyfinSessionContext>(),
      ),
    );
    gh.factory<_i169.MusicSearchCubit>(
      () => _i169.MusicSearchCubit(
        gh<_i747.MusicLibraryRepository>(),
        gh<_i747.PlaylistRepository>(),
      ),
    );
    gh.factory<_i213.PlaylistDetailCubit>(
      () => _i213.PlaylistDetailCubit(gh<_i747.MediaMetadataRepository>()),
    );
    gh.factory<_i213.ArtistDetailCubit>(
      () => _i213.ArtistDetailCubit(gh<_i747.MusicLibraryRepository>()),
    );
    gh.factory<_i213.AlbumDetailCubit>(
      () => _i213.AlbumDetailCubit(gh<_i747.MusicLibraryRepository>()),
    );
    gh.factory<_i618.ArtistsCubit>(
      () => _i618.ArtistsCubit(gh<_i747.MusicLibraryRepository>()),
    );
    gh.factory<_i618.AlbumsCubit>(
      () => _i618.AlbumsCubit(gh<_i747.MusicLibraryRepository>()),
    );
    gh.factory<_i618.SongsCubit>(
      () => _i618.SongsCubit(gh<_i747.MusicLibraryRepository>()),
    );
    return this;
  }
}

class _$DatabaseModule extends _i923.DatabaseModule {}

class _$SecureStorageModule extends _i318.SecureStorageModule {}

class _$JellyfinTransportModule extends _i748.JellyfinTransportModule {}
