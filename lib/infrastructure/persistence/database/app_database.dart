import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Jellyfinity's local database (ADR-0010).
///
/// SQLite via Drift. This is the foundational local-data store every later
/// media feature builds on: cached metadata, user-authored local state,
/// and (from v0.0.5's session work) the saved servers and profiles.
///
/// ## Schema versioning
///
/// [schemaVersion] starts at 1. Every schema change bumps it by one and
/// adds a step to [MigrationStrategy.onUpgrade] — the database is never
/// dropped and recreated on upgrade. The committed schema snapshots under
/// `drift_schemas/` are the reference for what each version looks like;
/// regenerate with `dart run drift_dev schema dump` after a schema change
/// and add a matching migration test.
///
/// ## Construction
///
/// Production wiring opens a lazily-resolved on-disk database (see
/// `DatabaseModule`). Tests construct `AppDatabase(NativeDatabase.memory())`
/// directly, so the suite never touches a platform channel or a real file.
@DriftDatabase(tables: [SavedServers, SavedAccounts, KeyValueEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await m.createIndex(_savedAccountsServerIdIndex);
      await m.createIndex(_savedServersBaseUrlIndex);
    },
    onUpgrade: (m, from, to) async {
      // v1 is the initial schema. Future versions add ordered steps here,
      // e.g. `if (from < 2) { await m.addColumn(...); }`.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static final Index _savedAccountsServerIdIndex = Index(
    'idx_saved_accounts_server_id',
    'CREATE INDEX IF NOT EXISTS idx_saved_accounts_server_id '
        'ON saved_accounts (server_id)',
  );

  static final Index _savedServersBaseUrlIndex = Index(
    'idx_saved_servers_base_url',
    'CREATE INDEX IF NOT EXISTS idx_saved_servers_base_url '
        'ON saved_servers (base_url)',
  );
}
