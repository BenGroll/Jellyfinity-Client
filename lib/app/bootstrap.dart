import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/AppConfig.dart';
import '../core/logging/Logger.dart';
import '../infrastructure/artwork/ArtworkCache.dart';
import '../infrastructure/persistence/LegacyJsonImporter.dart';
import 'di/service_locator.dart';
import 'session/SessionCubit.dart';

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
