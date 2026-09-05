@Tags(['migration'])
library;

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';

import '../../support/drift_schemas/schema.dart';
import '../../support/drift_schemas/schema_v1.dart' as v1;
import '../../support/drift_schemas/schema_v3.dart' as v3;
import '../../support/drift_schemas/schema_v4.dart' as v4;

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

  test('upgrades a v2 database to the v3 playback queue schema', () async {
    final schema = await verifier.schemaAt(2);
    final db = AppDatabase(schema.newConnection());

    await verifier.migrateAndValidate(db, 3);

    // Purely additive: the queue table exists and starts empty, same as
    // the v1 -> v2 cache tables did.
    expect(await db.select(db.queueEntries).get(), isEmpty);

    await db.close();
  });

  test('upgrades a v3 database to the v4 downloads schema', () async {
    final schema = await verifier.schemaAt(3);
    final db = AppDatabase(schema.newConnection());

    await verifier.migrateAndValidate(db, 4);

    // Additive again (v0.2.0): an install that upgrades starts with
    // nothing downloaded rather than losing what it had.
    expect(await db.select(db.trackDownloads).get(), isEmpty);
    expect(await db.select(db.downloadOwners).get(), isEmpty);

    await db.close();
  });

  test(
    'an upgrade to v4 keeps the queue an install was already holding',
    () async {
      final schema = await verifier.schemaAt(3);

      final old = v3.DatabaseAtV3(schema.newConnection());
      await old.customStatement(
        'INSERT INTO queue_entries (position, server_id, item_id, title) '
        "VALUES (0, 'server-1', 'track-1', 'So What')",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);

      final entries = await db.select(db.queueEntries).get();
      expect(entries.single.title, 'So What');

      await db.close();
    },
  );

  test(
    'upgrades a v4 database to the v5 playlist-download-members schema',
    () async {
      final schema = await verifier.schemaAt(4);
      final db = AppDatabase(schema.newConnection());

      await verifier.migrateAndValidate(db, 5);

      // Additive again (v0.2.1): the snapshot table exists and starts
      // empty; an upgrading install keeps every track and album download
      // it had and simply has no playlist snapshots yet.
      expect(await db.select(db.playlistDownloadMembers).get(), isEmpty);

      await db.close();
    },
  );

  test(
    'an upgrade to v5 keeps the downloads an install was already holding',
    () async {
      final schema = await verifier.schemaAt(4);

      final old = v4.DatabaseAtV4(schema.newConnection());
      await old.customStatement(
        'INSERT INTO track_downloads '
        '(server_id, item_id, state, title, requested_at) '
        "VALUES ('server-1', 'track-1', 'completed', 'So What', 0)",
      );
      await old.customStatement(
        'INSERT INTO download_owners '
        '(server_id, item_id, owner_kind, owner_item_id) '
        "VALUES ('server-1', 'track-1', 'track', 'track-1')",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 5);

      final downloads = await db.select(db.trackDownloads).get();
      expect(downloads.single.title, 'So What');
      expect(await db.select(db.downloadOwners).get(), hasLength(1));

      await db.close();
    },
  );
}
