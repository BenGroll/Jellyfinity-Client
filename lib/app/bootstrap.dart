import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../core/config/AppConfig.dart';
import '../core/logging/Logger.dart';
import '../domain/media/ArtworkResolver.dart';
import '../domain/playback/PlaybackEngine.dart';
import '../infrastructure/artwork/ArtworkCache.dart';
import '../infrastructure/persistence/key_value_store.dart';
import '../infrastructure/persistence/LegacyJsonImporter.dart';
import '../infrastructure/playback/JustAudioPlaybackEngine.dart';
import 'di/service_locator.dart';
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
