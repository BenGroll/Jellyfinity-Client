import 'package:drift_flutter/drift_flutter.dart';
import 'package:injectable/injectable.dart';

import 'database/AppDatabase.dart';

/// DI wiring for the local database (ADR-0010).
///
/// [AppDatabase] is registered as a lazy singleton over a connection that
/// resolves its file path from `path_provider` only on the first query, so
/// constructing it during `configureDependencies()` touches no platform
/// channel. The database file is `jellyfinity.sqlite` in the application
/// support directory.
@module
abstract class DatabaseModule {
  @lazySingleton
  AppDatabase appDatabase() => AppDatabase(driftDatabase(name: 'jellyfinity'));
}
