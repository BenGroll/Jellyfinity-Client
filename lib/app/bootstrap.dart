import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../core/config/AppConfig.dart';
import '../core/logging/Logger.dart';
import '../domain/connectivity/OfflineLibraryScope.dart';
import '../domain/media/ArtworkResolver.dart';
import '../domain/playback/CrossfadeSettings.dart';
import '../domain/playback/NormalizationSettings.dart';
import '../domain/playback/PlaybackEngine.dart';
import '../domain/playback/stream_quality.dart';
import '../infrastructure/artwork/ArtworkCache.dart';
import '../infrastructure/persistence/key_value_store.dart';
import '../infrastructure/persistence/LegacyJsonImporter.dart';
import '../infrastructure/playback/JustAudioPlaybackEngine.dart';
import 'di/service_locator.dart';
import 'downloads/DownloadsCubit.dart';
import 'playback/PlaybackCubit.dart';
import 'session/SessionCubit.dart';
import 'settings/SettingsCubit.dart';
import 'settings/ShellNavigationMode.dart';

/// Boots the application: wires configuration, dependency injection, and
/// global error handling before the widget tree is built.
///
/// This is the application's composition root's entry point. It is kept
/// as a plain function (rather than living inline in `main()`) so it can
/// be exercised by tests without also running `main()` or spinning up a
/// real Flutter binding target.
Future<void> bootstrap({required Widget Function() builder}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  getIt.registerSingleton<AppConfig>(config);

  // Bound decoded artwork in memory before any of it is loaded
  // (ADR-0010's artwork cache; the disk half bounds itself).
  ArtworkCache.configureImageCache();

  await configureDependencies();

  // ShellNavigationMode can't be an @preResolve @module method (as
  // JellyfinClientIdentity's device-id lookup is): injectable_generator
  // cannot resolve a module method whose return type is an enum
  // (`EnumElementImpl is not a subtype of ClassElement`). So, like
  // PlaybackEngine below (for an unrelated reason), it is read here and
  // registered with getIt directly — still before `runApp`, so the first
  // frame already renders in the saved navigation mode rather than
  // flashing the default and then swapping.
  final initialNavigationMode = await SettingsCubit.loadInitialNavigationMode(
    getIt<KeyValueStore>(),
  );
  getIt.registerSingleton<ShellNavigationMode>(initialNavigationMode);

  // Same enum-can't-be-an-@preResolve-module-method constraint as
  // ShellNavigationMode above.
  final initialStreamQuality = await SettingsCubit.loadInitialStreamQuality(
    getIt<KeyValueStore>(),
  );
  getIt.registerSingleton<StreamQuality>(initialStreamQuality);

  // The download-quality (v0.2.2) preference, read the same way and for
  // the same reason: DownloadsCubit reads it through SettingsCubit and
  // the first frame's download controls should reflect the saved choice.
  // Registered under a name because a plain StreamQuality is already
  // taken by streaming above.
  final startingDownloadQuality =
      await SettingsCubit.loadInitialDownloadQuality(getIt<KeyValueStore>());
  getIt.registerSingleton<StreamQuality>(
    startingDownloadQuality,
    instanceName: initialDownloadQuality,
  );

  // Wi-Fi-only downloads (v0.2.2). A bool, so it too takes a name.
  final startingDownloadsWifiOnly =
      await SettingsCubit.loadInitialDownloadsWifiOnly(getIt<KeyValueStore>());
  getIt.registerSingleton<bool>(
    startingDownloadsWifiOnly,
    instanceName: initialDownloadsWifiOnly,
  );

  // The offline-library-scope preference (v0.2.3). Enum, so registered
  // directly like ShellNavigationMode above.
  final initialOfflineLibraryScope =
      await SettingsCubit.loadInitialOfflineLibraryScope(getIt<KeyValueStore>());
  getIt.registerSingleton<OfflineLibraryScope>(initialOfflineLibraryScope);

  // Crossfade (ADR-0016) is read here too, so the engine is configured
  // before the restored queue is primed rather than after — a saved
  // crossfade preference is in force from the first transition, not the
  // second.
  final initialCrossfade = await SettingsCubit.loadInitialCrossfade(
    getIt<KeyValueStore>(),
  );
  getIt.registerSingleton<CrossfadeSettings>(initialCrossfade);

  // Normalization (v0.1.4) is read here for the same reason crossfade is:
  // the engine should be configured before the restored queue is primed.
  final initialNormalization = await SettingsCubit.loadInitialNormalization(
    getIt<KeyValueStore>(),
  );
  getIt.registerSingleton<NormalizationSettings>(initialNormalization);

  // JustAudioPlaybackEngine is BaseAudioHandler itself, and AudioService
  // .init() can only ever be called once per process — that makes it a
  // poor fit for an @preResolve DI module (configureDependencies() runs
  // fresh in every test), unlike JellyfinClientIdentity's device-id
  // lookup, which is safely repeatable. So, like AppConfig above, it is
  // constructed here and registered with getIt directly, kept out of the
  // generated graph and everything that exercises it in tests.
  final playbackEngine = await AudioService.init(
    builder: () => JustAudioPlaybackEngine(getIt<ArtworkResolver>()),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'io.nachbar.jellyfinity.playback',
      androidNotificationChannelName: 'Playback',
    ),
  );
  getIt.registerSingleton<PlaybackEngine>(playbackEngine);

  final logger = getIt<Logger>();

  // One-time migration of v0.0.5's interim JSON store into the database.
  // Awaited (it is a no-op after the first run, or on a fresh install) so
  // that session restore below reads the imported servers and profiles.
  await getIt<LegacyJsonImporter>().run();

  // Kick off session restore without awaiting it: the app launches at
  // SessionStatus.unknown (the splash screen) and the SessionCubit moves
  // it to the shell or onboarding once storage has been read. Restore
  // does no network call, so a currently-offline server does not block
  // startup.
  unawaited(getIt<SessionCubit>().restore());

  // Primes the engine with the saved queue, paused, so leaving the app
  // mid-album and reopening it later shows where playback left off
  // without a surprise auto-play at launch.
  unawaited(getIt<PlaybackCubit>().restore());

  // Reads the download records and resumes anything the last run was
  // interrupted mid-transfer (v0.2.0). Unawaited for the same reason the
  // two restores above are: it touches storage, not the network, and the
  // first frame should not wait on it.
  unawaited(getIt<DownloadsCubit>().restore());

  FlutterError.onError = (details) {
    logger.error(
      'Unhandled Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  runZonedGuarded(
    () {
      logger.info(
        'Jellyfinity starting (environment: '
        '${config.environment.name})',
      );
      runApp(builder());
    },
    (error, stackTrace) {
      logger.error(
        'Unhandled error outside Flutter',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}
