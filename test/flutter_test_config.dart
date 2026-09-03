import 'dart:async';

import 'package:drift/drift.dart';

/// Runs once before any test in the suite.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Several persistence tests deliberately open more than one database in a
  // single process (a store plus a "reloaded" store, two independent
  // databases, ...). That is intentional here, so silence drift's
  // development-only warning about it.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  await testMain();
}
