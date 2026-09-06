@Tags(['migration'])
library;

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';

import '../../support/drift_schemas/schema.dart';
import '../../support/drift_schemas/schema_v1.dart' as v1;
import '../../support/drift_schemas/schema_v3.dart' as v3;
import '../../support/drift_schemas/schema_v4.dart' as v4;
import '../../support/drift_schemas/schema_v5.dart' as v5;

/// The forward-only migration policy ADR-0010 committed to: a schema
/// change never drops the database, and an install on any past version
/// upgrades to the current one with its data intact.
///
/// `SchemaVerifier.migrateAndValidate(db, n)` runs the full `onUpgrade`
/// chain to the latest schema and then diffs the result against the
/// committed snapshot for version `n`, tolerating tables added after `n`
/// but flagging any change to a table `n` already had. So a step that
/// only *adds* tables (v1–v5) is still checked against its own version;
/// v6, which reshapes the three download tables, is checked against v6.
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

  test('upgrades a v3 database to the current downloads schema', () async {
    final schema = await verifier.schemaAt(3);
    final db = AppDatabase(schema.newConnection());

    await verifier.migrateAndValidate(db, 6);

    // An install that upgrades from before downloads existed starts with
    // nothing downloaded rather than losing what it had.
    expect(await db.select(db.trackDownloads).get(), isEmpty);
    expect(await db.select(db.downloadOwners).get(), isEmpty);

    await db.close();
  });

  test(
    'an upgrade from v3 keeps the queue an install was already holding',
    () async {
      final schema = await verifier.schemaAt(3);

      final old = v3.DatabaseAtV3(schema.newConnection());
      await old.customStatement(
        'INSERT INTO queue_entries (position, server_id, item_id, title) '
        "VALUES (0, 'server-1', 'track-1', 'So What')",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 6);

      final entries = await db.select(db.queueEntries).get();
      expect(entries.single.title, 'So What');

      await db.close();
    },
  );

  test(
    'upgrades a v4 database to the current playlist-downloads schema',
    () async {
      final schema = await verifier.schemaAt(4);
      final db = AppDatabase(schema.newConnection());

      await verifier.migrateAndValidate(db, 6);

      // Additive at v5 (v0.2.1): the snapshot table exists and starts
      // empty; an upgrading install keeps every track and album download
      // it had and simply has no playlist snapshots yet.
      expect(await db.select(db.playlistDownloadMembers).get(), isEmpty);

      await db.close();
    },
  );

  test(
    'an upgrade from v4 keeps the downloads an install was already holding',
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
      await verifier.migrateAndValidate(db, 6);

      final downloads = await db.select(db.trackDownloads).get();
      expect(downloads.single.title, 'So What');
      expect(await db.select(db.downloadOwners).get(), hasLength(1));

      await db.close();
    },
  );

  test(
    'upgrades a v5 database to the v6 per-profile downloads schema',
    () async {
      final schema = await verifier.schemaAt(5);
      final db = AppDatabase(schema.newConnection());

      await verifier.migrateAndValidate(db, 6);

      // The downloaded-collection identity table is new and starts empty;
      // a collection's name and artwork fill in the next time it is
      // downloaded or opened online.
      expect(await db.select(db.downloadedCollections).get(), isEmpty);

      await db.close();
    },
  );

  test(
    'an upgrade to v6 keeps existing downloads and leaves them unclaimed',
    () async {
      final schema = await verifier.schemaAt(5);

      final old = v5.DatabaseAtV5(schema.newConnection());
      await old.customStatement(
        'INSERT INTO track_downloads '
        '(server_id, item_id, state, title, requested_at) '
        "VALUES ('server-1', 'track-1', 'completed', 'So What', 0)",
      );
      await old.customStatement(
        'INSERT INTO download_owners '
        '(server_id, item_id, owner_kind, owner_item_id) '
        "VALUES ('server-1', 'track-1', 'album', 'album-1')",
      );
      await old.customStatement(
        'INSERT INTO playlist_download_members '
        '(server_id, playlist_item_id, position, track_item_id) '
        "VALUES ('server-1', 'playlist-1', 0, 'track-1')",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 6);

      // Data is preserved; the new account_key defaults to empty, which
      // `DownloadsCubit.restore` then claims for the first profile to sign
      // in after the upgrade.
      final downloads = await db.select(db.trackDownloads).get();
      expect(downloads.single.title, 'So What');
      expect(downloads.single.accountKey, '');
      expect(downloads.single.serverGone, isFalse);
      expect((await db.select(db.downloadOwners).get()).single.accountKey, '');
      expect(
        (await db.select(db.playlistDownloadMembers).get()).single.accountKey,
        '',
      );

      await db.close();
    },
  );
}
