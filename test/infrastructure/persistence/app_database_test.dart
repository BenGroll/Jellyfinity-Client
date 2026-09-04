import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';

import '../../support/test_database.dart';

void main() {
  group('AppDatabase schema', () {
    late AppDatabase db;

    setUp(() => db = newTestDatabase());
    tearDown(() => db.close());

    test('is at schema version 1', () {
      expect(db.schemaVersion, 1);
    });

    test('creates every declared table', () async {
      final names =
          (await db
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'table'",
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();

      expect(
        names,
        containsAll(<String>[
          'saved_servers',
          'saved_accounts',
          'key_value_entries',
        ]),
      );
    });

    test('creates the indexes the migration declares', () async {
      final indexes =
          (await db
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'index'",
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();

      expect(indexes, contains('idx_saved_accounts_server_id'));
      expect(indexes, contains('idx_saved_servers_base_url'));
    });

    test('enables foreign-key enforcement on open', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.read<int>('foreign_keys'), 1);
    });
  });

  test('reopening the same database file preserves data (no destructive '
      'migration)', () async {
    final dir = Directory.systemTemp.createTempSync('jellyfinity_db_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/app.sqlite');

    final first = AppDatabase(NativeDatabase(file));
    await first
        .into(first.keyValueEntries)
        .insert(
          KeyValueEntriesCompanion.insert(key: 'k', value: 'v', updatedAt: 0),
        );
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final row = await (second.select(
      second.keyValueEntries,
    )..where((t) => t.key.equals('k'))).getSingle();
    expect(row.value, 'v');
    expect(second.schemaVersion, 1);
  });
}
