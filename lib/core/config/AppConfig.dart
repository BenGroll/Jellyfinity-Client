import 'package:flutter/foundation.dart';

/// Application-wide configuration.
///
/// Jellyfinity has no build-flavor system yet, and does not need one for
/// v0.0.2. Configuration is intentionally simple: compile-time values are
/// read from `--dart-define` (see [AppConfig.fromEnvironment]), with
/// sensible defaults for local development so the app runs correctly
/// with zero flags.
///
/// This is the place to add fields as real configuration needs appear
/// (e.g. a default/first-run server URL for development). Do not grow
/// this into a general-purpose settings store — user-facing preferences
/// belong to a future persistence-layer feature (see the v0.0.6
/// milestone), not to build-time configuration.
class AppConfig {
  const AppConfig({required this.environment});

  /// Reads configuration from compile-time environment variables passed
  /// via `--dart-define`, falling back to development-friendly defaults.
  ///
  /// Example: `flutter run --dart-define=ENVIRONMENT=production`
  factory AppConfig.fromEnvironment() {
    const environmentName = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'development',
    );
    return AppConfig(
      environment: AppEnvironment.values.firstWhere(
        (value) => value.name == environmentName,
        orElse: () => AppEnvironment.development,
      ),
    );
  }

  final AppEnvironment environment;

  bool get isDevelopment => environment == AppEnvironment.development;

  bool get isProduction => environment == AppEnvironment.production;

  /// Whether verbose/debug-level diagnostics should be enabled. Tied to
  /// the Flutter build mode rather than [environment], since debug
  /// logging should never run in a release binary regardless of the
  /// configured environment.
  bool get verboseLoggingEnabled => kDebugMode;
}

enum AppEnvironment { development, production }
