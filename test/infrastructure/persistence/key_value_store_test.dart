import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/persistence/database/app_database.dart';
import 'package:jellyfinity/infrastructure/persistence/key_value_store.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late KeyValueStore store;

  setUp(() {
    db = newTestDatabase();
    store = DriftKeyValueStore(db);
  });
  tearDown(() => db.close());

  test('returns null for every type when a key is absent', () async {
    expect(await store.getString('x'), isNull);
    expect(await store.getBool('x'), isNull);
    expect(await store.getInt('x'), isNull);
    expect(await store.getDouble('x'), isNull);
  });

  test('round-trips each typed value', () async {
    await store.setString('s', 'hello');
    await store.setBool('b', true);
    await store.setInt('i', 42);
    await store.setDouble('d', 3.5);

    expect(await store.getString('s'), 'hello');
    expect(await store.getBool('b'), true);
    expect(await store.getInt('i'), 42);
    expect(await store.getDouble('d'), 3.5);
  });

  test('overwrites an existing key rather than inserting twice', () async {
    await store.setInt('i', 1);
    await store.setInt('i', 2);

    expect(await store.getInt('i'), 2);
    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM key_value_entries')
        .getSingle();
    expect(count.read<int>('c'), 1);
  });

  test('remove() deletes a key and is a no-op when it is absent', () async {
    await store.setString('s', 'v');
    await store.remove('s');
    expect(await store.getString('s'), isNull);

    await store.remove('never-there');
  });
}
