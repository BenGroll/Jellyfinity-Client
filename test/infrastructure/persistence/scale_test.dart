@Tags(['scale'])
library;

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';

import '../../support/test_database.dart';

/// Exercises the database stack at a row count representative of the
/// development music library (~130k tracks — see `PHILOSOPHY.md` §11).
///
/// There is no media table until v0.0.7, so this uses `key_value_entries`
/// as a stand-in to prove the mechanics that large-library features will
/// depend on: batched bulk insert inside a transaction, an indexed point
/// lookup that stays fast at scale, and keyset/offset pagination that
/// never loads the whole set into memory. Real media-scale query tests
/// arrive with the music library in v0.0.8.
void main() {
  const rowCount = 130000;

  late AppDatabase db;
  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  test('bulk insert, indexed lookup and pagination at ~130k rows', () async {
    final insert = Stopwatch()..start();
    await db.batch((batch) {
      batch.insertAll(db.keyValueEntries, [
        for (var i = 0; i < rowCount; i++)
          KeyValueEntriesCompanion.insert(
            key: 'track:${i.toString().padLeft(7, '0')}',
            value: 'artist ${i % 900}',
            updatedAt: i,
          ),
      ]);
    });
    insert.stop();

    final total = await db
        .customSelect('SELECT COUNT(*) AS c FROM key_value_entries')
        .getSingle();
    expect(total.read<int>('c'), rowCount);

    // Indexed point lookup on the primary key.
    final lookup = Stopwatch()..start();
    final one = await (db.select(
      db.keyValueEntries,
    )..where((t) => t.key.equals('track:0091234'))).getSingle();
    lookup.stop();
    expect(one.value, 'artist ${91234 % 900}');
    expect(
      lookup.elapsedMilliseconds,
      lessThan(50),
      reason: 'a primary-key lookup must not scan the table',
    );

    // Page through the collection without ever materialising all of it.
    var seen = 0;
    const pageSize = 500;
    for (var offset = 0; offset < rowCount; offset += pageSize) {
      final page =
          await (db.select(db.keyValueEntries)
                ..orderBy([(t) => OrderingTerm(expression: t.key)])
                ..limit(pageSize, offset: offset))
              .get();
      seen += page.length;
      expect(page.length, lessThanOrEqualTo(pageSize));
    }
    expect(seen, rowCount);

    // Generous ceilings — this is a smoke test for "does not fall over",
    // not a benchmark.
    expect(
      insert.elapsedMilliseconds,
      lessThan(20000),
      reason: 'batched insert of $rowCount rows should be well under 20s',
    );
  });
}
