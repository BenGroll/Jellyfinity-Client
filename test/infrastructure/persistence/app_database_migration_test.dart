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
import '../../support/drift_schemas/schema_v6.dart' as v6;
import '../../support/drift_schemas/schema_v7.dart' as v7;
import '../../support/drift_schemas/schema_v9.dart' as v9;

/// The forward-only migration policy ADR-0010 committed to: a schema
/// change never drops the database, and an install on any past version
/// upgrades to the current one with its data intact.
///
/// `SchemaVerifier.migrateAndValidate(db, n)` runs the full `onUpgrade`
/// chain to the latest schema and then diffs the result against the
/// committed snapshot for version `n`, tolerating tables added after `n`
/// but flagging any change to a table `n` already had. So once a step
/// reshapes an existing table, every test past that point has to assert
/// the current schema: v6 reshaped the download tables and v7 (v0.3.1)
/// widened `queue_entries`, so every intermediate check now validates at
/// HEAD.
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

  test('upgrades a v2 database to the current schema', () async {
    final schema = await verifier.schemaAt(2);
    final db = AppDatabase(schema.newConnection());

    await verifier.migrateAndValidate(db, 10);

    // Purely additive at v3: the queue table exists and starts empty, same
    // as the v1 -> v2 cache tables did.
    expect(await db.select(db.queueEntries).get(), isEmpty);

    await db.close();
  });

  test('upgrades a v3 database to the current schema', () async {
    final schema = await verifier.schemaAt(3);
    final db = AppDatabase(schema.newConnection());

    await verifier.migrateAndValidate(db, 10);

    // An install that upgrades from before downloads existed starts with
    // nothing downloaded rather than losing what it had.
    expect(await db.select(db.trackDownloads).get(), isEmpty);
    expect(await db.select(db.downloadOwners).get(), isEmpty);
    // Listening history (v0.3.1) is new and starts empty.
    expect(await db.select(db.listeningHistoryEntries).get(), isEmpty);

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
      await verifier.migrateAndValidate(db, 10);

      final entries = await db.select(db.queueEntries).get();
      expect(entries.single.title, 'So What');
      // The v7 columns are added nullable, so a pre-v7 row keeps its data
      // and simply carries no album or artist ids.
      expect(entries.single.albumItemId, isNull);
      expect(entries.single.artistsJson, isNull);

      await db.close();
    },
  );

  test('upgrades a v4 database to the current schema', () async {
    final schema = await verifier.schemaAt(4);
    final db = AppDatabase(schema.newConnection());

    await verifier.migrateAndValidate(db, 10);

    // Additive at v5 (v0.2.1): the snapshot table exists and starts
    // empty; an upgrading install keeps every track and album download
    // it had and simply has no playlist snapshots yet.
    expect(await db.select(db.playlistDownloadMembers).get(), isEmpty);

    await db.close();
  });

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
      await verifier.migrateAndValidate(db, 10);

      final downloads = await db.select(db.trackDownloads).get();
      expect(downloads.single.title, 'So What');
      expect(await db.select(db.downloadOwners).get(), hasLength(1));

      await db.close();
    },
  );

  test('upgrades a v5 database to the current schema', () async {
    final schema = await verifier.schemaAt(5);
    final db = AppDatabase(schema.newConnection());

    await verifier.migrateAndValidate(db, 10);

    // The downloaded-collection identity table is new and starts empty;
    // a collection's name and artwork fill in the next time it is
    // downloaded or opened online.
    expect(await db.select(db.downloadedCollections).get(), isEmpty);

    await db.close();
  });

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
      await verifier.migrateAndValidate(db, 10);

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

  test('upgrades a v6 database to the v7 listening-history schema', () async {
    final schema = await verifier.schemaAt(6);
    final db = AppDatabase(schema.newConnection());

    await verifier.migrateAndValidate(db, 10);

    // Listening history is new and starts empty; it begins accruing from
    // the next qualifying play.
    expect(await db.select(db.listeningHistoryEntries).get(), isEmpty);

    await db.close();
  });

  test('an upgrade from v6 keeps a queued track and widens its row', () async {
    final schema = await verifier.schemaAt(6);

    final old = v6.DatabaseAtV6(schema.newConnection());
    await old.customStatement(
      'INSERT INTO queue_entries (position, server_id, item_id, title) '
      "VALUES (0, 'server-1', 'track-1', 'So What')",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 10);

    final entries = await db.select(db.queueEntries).get();
    expect(entries.single.title, 'So What');
    expect(entries.single.albumItemId, isNull);
    expect(entries.single.artistsJson, isNull);

    await db.close();
  });

  test('upgrades a v7 database to the v8 favorites cache', () async {
    final schema = await verifier.schemaAt(7);
    final db = AppDatabase(schema.newConnection());

    await verifier.migrateAndValidate(db, 10);

    // The favorites cache is new and starts empty; it fills in the first
    // time the Favorites screen is opened online (ADR-0028).
    expect(await db.select(db.cachedFavorites).get(), isEmpty);

    await db.close();
  });

  test('an upgrade from v7 keeps a queued track and its history', () async {
    final schema = await verifier.schemaAt(7);

    final old = v7.DatabaseAtV7(schema.newConnection());
    await old.customStatement(
      'INSERT INTO queue_entries (position, server_id, item_id, title) '
      "VALUES (0, 'server-1', 'track-1', 'So What')",
    );
    await old.customStatement(
      'INSERT INTO listening_history_entries '
      '(account_key, server_id, context_kind, context_item_id, name, '
      'first_played_at_ms, last_played_at_ms) '
      "VALUES ('server-1/user-1', 'server-1', 'album', 'album-1', "
      "'Kind of Blue', 1, 2)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 10);

    expect((await db.select(db.queueEntries).get()).single.title, 'So What');
    expect(
      (await db.select(db.listeningHistoryEntries).get()).single.name,
      'Kind of Blue',
    );

    await db.close();
  });

  test('upgrades a v9 database to the v10 pending-favorites schema', () async {
    final schema = await verifier.schemaAt(9);
    final db = AppDatabase(schema.newConnection());

    await verifier.migrateAndValidate(db, 10);

    // Pending favorite intents are new and start empty; nothing was
    // toggled offline before this version existed.
    expect(await db.select(db.pendingFavoriteIntents).get(), isEmpty);

    await db.close();
  });

  test('an upgrade from v9 keeps a favorite an install already had', () async {
    final schema = await verifier.schemaAt(9);

    final old = v9.DatabaseAtV9(schema.newConnection());
    await old.customStatement(
      'INSERT INTO cached_favorites '
      '(account_key, server_id, item_id, kind, updated_at) '
      "VALUES ('server-1/user-1', 'server-1', 'album-1', 'album', 1)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 10);

    final favorites = await db.select(db.cachedFavorites).get();
    expect(favorites.single.itemId, 'album-1');
    expect(await db.select(db.pendingFavoriteIntents).get(), isEmpty);

    await db.close();
  });
}
