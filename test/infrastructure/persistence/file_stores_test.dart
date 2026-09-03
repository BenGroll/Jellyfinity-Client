import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/session/jellyfin_account.dart';
import 'package:jellyfinity/domain/session/jellyfin_server.dart';
import 'package:jellyfinity/infrastructure/persistence/file_account_store.dart';
import 'package:jellyfinity/infrastructure/persistence/file_server_registry.dart';
import 'package:jellyfinity/infrastructure/persistence/json_store.dart';

import '../../support/test_logger.dart';

void main() {
  late Directory dir;
  JsonStore newStore() => FileJsonStore(() async => dir, TestLogger());

  setUp(() {
    dir = Directory.systemTemp.createTempSync('jellyfinity_stores_test');
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  const server = JellyfinServer(
    id: 's1',
    baseUrl: 'https://media.example.com',
    name: 'Home Media',
    reportedVersion: '10.11.6',
    serverId: 'jf-1',
  );

  group('FileServerRegistry', () {
    test('persists a saved server across store instances', () async {
      await FileServerRegistry(newStore()).save(server);

      final reloaded = await FileServerRegistry(newStore()).all();
      expect(reloaded, [server]);
    });

    test('save replaces the entry with the same id', () async {
      final registry = FileServerRegistry(newStore());
      await registry.save(server);
      await registry.save(server.copyWith(name: 'Renamed'));

      final all = await registry.all();
      expect(all, hasLength(1));
      expect(all.single.name, 'Renamed');
    });

    test('looks a server up by normalized base URL', () async {
      final registry = FileServerRegistry(newStore());
      await registry.save(server);

      expect(await registry.byBaseUrl('https://media.example.com'), server);
      expect(await registry.byBaseUrl('https://other.example'), isNull);
    });

    test('remove deletes the entry', () async {
      final registry = FileServerRegistry(newStore());
      await registry.save(server);
      await registry.remove('s1');

      expect(await registry.all(), isEmpty);
    });
  });

  group('FileAccountStore', () {
    const account = JellyfinAccount(
      id: 'a1',
      serverId: 's1',
      userId: 'u1',
      username: 'alice',
    );

    test('persists accounts and the active pointer across instances', () async {
      final store = FileAccountStore(newStore());
      await store.save(account);
      await store.setActiveAccountId('a1');

      final reloaded = FileAccountStore(newStore());
      expect(await reloaded.all(), [account]);
      expect(await reloaded.activeAccountId(), 'a1');
    });

    test('byServerAndUser finds a re-login of a saved profile', () async {
      final store = FileAccountStore(newStore());
      await store.save(account);

      expect(await store.byServerAndUser('s1', 'u1'), account);
      expect(await store.byServerAndUser('s1', 'other'), isNull);
    });

    test('removing the active account clears the active pointer', () async {
      final store = FileAccountStore(newStore());
      await store.save(account);
      await store.setActiveAccountId('a1');

      await store.remove('a1');

      expect(await store.activeAccountId(), isNull);
    });

    test('setting an unknown active account is rejected', () async {
      final store = FileAccountStore(newStore());
      expect(() => store.setActiveAccountId('ghost'), throwsArgumentError);
    });

    test('forServer filters by server id', () async {
      final store = FileAccountStore(newStore());
      await store.save(account);
      await store.save(
        const JellyfinAccount(
          id: 'a2',
          serverId: 's2',
          userId: 'u2',
          username: 'bob',
        ),
      );

      final forS1 = await store.forServer('s1');
      expect(forS1.map((a) => a.id), ['a1']);
    });
  });
}
