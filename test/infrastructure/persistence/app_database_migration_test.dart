@Tags(['migration'])
library;

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';

import '../../support/drift_schemas/schema.dart';
import '../../support/drift_schemas/schema_v1.dart' as v1;

/// The forward-only migration policy ADR-0010 committed to: a schema
/// change never drops the database, and the step from v(N-1) to vN is
/// proven against the committed snapshot in `drift_schemas/` rather than
/// against whatever the current code happens to produce.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('upgrades a v1 database to the v2 media cache schema', () async {
    final schema = await verifier.schemaAt(1);
    final db = AppDatabase(schema.newConnection());

    await verifier.migrateAndValidate(db, 2);

    await db.close();
  });

  test('keeps saved servers and profiles across the upgrade', () async {
    final schema = await verifier.schemaAt(1);

    final old = v1.DatabaseAtV1(schema.newConnection());
    await old.customStatement(
      'INSERT INTO saved_servers '
      '(id, base_url, name, reported_version, added_at) '
      "VALUES ('server-1', 'https://media.example.org', 'Home', '10.11.6', 1)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);

    final servers = await db.select(db.savedServers).get();
    expect(servers.single.name, 'Home');
    // The new tables exist and start empty; an upgrading install has a
    // cache to fill, not a library to lose.
    expect(await db.select(db.cachedMediaItems).get(), isEmpty);

    await db.close();
  });
}
