import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';
import 'package:jellyfinity/infrastructure/persistence/device_identity_store.dart';
import 'package:jellyfinity/infrastructure/persistence/key_value_store.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  test(
    'generates an id once and returns the same one on later calls',
    () async {
      final store = PersistentDeviceIdentityStore(DriftKeyValueStore(db));

      final first = await store.deviceId();
      final second = await store.deviceId();

      expect(first, isNotEmpty);
      expect(second, first);
    },
  );

  test('the id survives a fresh store instance (it is persisted)', () async {
    final id = await PersistentDeviceIdentityStore(
      DriftKeyValueStore(db),
    ).deviceId();

    final reloaded = await PersistentDeviceIdentityStore(
      DriftKeyValueStore(db),
    ).deviceId();

    expect(reloaded, id);
  });

  test('two separate databases get distinct ids', () async {
    final a = await PersistentDeviceIdentityStore(
      DriftKeyValueStore(db),
    ).deviceId();

    final otherDb = newTestDatabase();
    addTearDown(otherDb.close);
    final b = await PersistentDeviceIdentityStore(
      DriftKeyValueStore(otherDb),
    ).deviceId();

    expect(a, isNot(b));
  });
}
