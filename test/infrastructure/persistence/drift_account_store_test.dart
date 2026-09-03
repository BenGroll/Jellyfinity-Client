import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/session/jellyfin_account.dart';
import 'package:jellyfinity/infrastructure/persistence/database/app_database.dart';
import 'package:jellyfinity/infrastructure/persistence/drift_account_store.dart';
import 'package:jellyfinity/infrastructure/persistence/key_value_store.dart';

import '../../support/test_database.dart';

JellyfinAccount _account(
  String id, {
  String serverId = 's1',
  String userId = 'u1',
  String username = 'alice',
}) => JellyfinAccount(
  id: id,
  serverId: serverId,
  userId: userId,
  username: username,
);

void main() {
  late AppDatabase db;
  late DriftAccountStore store;

  setUp(() {
    db = newTestDatabase();
    store = DriftAccountStore(db, DriftKeyValueStore(db));
  });
  tearDown(() => db.close());

  test('saves, lists in insertion order, and filters by server', () async {
    await store.save(_account('a', serverId: 's1'));
    await store.save(_account('b', serverId: 's2'));
    await store.save(_account('c', serverId: 's1'));

    expect((await store.all()).map((a) => a.id), ['a', 'b', 'c']);
    expect((await store.forServer('s1')).map((a) => a.id), ['a', 'c']);
  });

  test('byServerAndUser finds a re-login of a saved profile', () async {
    await store.save(_account('a', serverId: 's1', userId: 'u1'));

    expect((await store.byServerAndUser('s1', 'u1'))?.id, 'a');
    expect(await store.byServerAndUser('s1', 'other'), isNull);
  });

  test('save() replaces an entry with the same id', () async {
    await store.save(_account('a', username: 'alice'));
    await store.save(_account('a', username: 'alice2'));

    final all = await store.all();
    expect(all, hasLength(1));
    expect(all.single.username, 'alice2');
  });

  group('active-account pointer', () {
    test('is null until set, round-trips, and clears', () async {
      expect(await store.activeAccountId(), isNull);

      await store.save(_account('a'));
      await store.setActiveAccountId('a');
      expect(await store.activeAccountId(), 'a');

      await store.setActiveAccountId(null);
      expect(await store.activeAccountId(), isNull);
    });

    test('rejects an id that is not a saved account', () async {
      expect(
        () => store.setActiveAccountId('ghost'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'remove() clears the pointer when it was the active account',
      () async {
        await store.save(_account('a'));
        await store.save(_account('b'));
        await store.setActiveAccountId('a');

        await store.remove('a');

        expect(await store.activeAccountId(), isNull);
        expect((await store.all()).map((a) => a.id), ['b']);
      },
    );

    test('remove() leaves the pointer alone for a different account', () async {
      await store.save(_account('a'));
      await store.save(_account('b'));
      await store.setActiveAccountId('a');

      await store.remove('b');

      expect(await store.activeAccountId(), 'a');
    });
  });
}
