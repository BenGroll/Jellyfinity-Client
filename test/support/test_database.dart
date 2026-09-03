import 'package:drift/native.dart';
import 'package:jellyfinity/infrastructure/persistence/database/app_database.dart';

/// A fresh in-memory [AppDatabase] for a single test. Runs the real
/// migration (`onCreate`), so tables, indexes and pragmas match production.
///
/// The multi-database warning is silenced suite-wide in
/// `test/flutter_test_config.dart`.
AppDatabase newTestDatabase() => AppDatabase(NativeDatabase.memory());
