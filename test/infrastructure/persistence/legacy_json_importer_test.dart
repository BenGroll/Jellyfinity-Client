import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/session/JellyfinServer.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';
import 'package:jellyfinity/infrastructure/persistence/DriftAccountStore.dart';
import 'package:jellyfinity/infrastructure/persistence/DriftServerRegistry.dart';
import 'package:jellyfinity/infrastructure/persistence/key_value_store.dart';
import 'package:jellyfinity/infrastructure/persistence/LegacyJsonImporter.dart';

import '../../support/test_database.dart';
import '../../support/TestLogger.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late LegacyJsonImporter importer;
  late DriftServerRegistry servers;
  late DriftAccountStore accounts;

  setUp(() {
    db = newTestDatabase();
    final keyValue = DriftKeyValueStore(db);
    servers = DriftServerRegistry(db);
    accounts = DriftAccountStore(db, keyValue);
    dir = Directory.systemTemp.createTempSync('jellyfinity_import_test_');
    importer = LegacyJsonImporter(db, keyValue, TestLogger())
      ..directoryProvider = (() async => dir);
  });
  tearDown(() {
    db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  void writeLegacy({
    List<Map<String, dynamic>> serverRows = const [],
    List<Map<String, dynamic>> accountRows = const [],
    String? activeAccountId,
  }) {
    File(
      '${dir.path}/servers.json',
    ).writeAsStringSync(jsonEncode({'servers': serverRows}));
    final accountsDoc = <String, dynamic>{'accounts': accountRows};
    if (activeAccountId != null) {
      accountsDoc['activeAccountId'] = activeAccountId;
    }
    File(
      '${dir.path}/accounts.json',
    ).writeAsStringSync(jsonEncode(accountsDoc));
  }

  test('imports servers, profiles and the active pointer, then retires the '
      'files', () async {
    writeLegacy(
      serverRows: [
        {
          'id': 's1',
          'baseUrl': 'https://a',
          'name': 'A',
          'reportedVersion': '10.11.6',
          'serverId': 'jf-a',
        },
        {'id': 's2', 'baseUrl': 'https://b', 'name': 'B'},
      ],
      accountRows: [
        {'id': 'p1', 'serverId': 's1', 'userId': 'u1', 'username': 'alice'},
        {'id': 'p2', 'serverId': 's2', 'userId': 'u2', 'username': 'bob'},
      ],
      activeAccountId: 'p2',
    );

    await importer.run();

    expect((await servers.all()).map((s) => s.id), ['s1', 's2']);
    expect((await servers.byId('s2'))?.reportedVersion, '');
    expect((await accounts.all()).map((a) => a.id), ['p1', 'p2']);
    expect(await accounts.activeAccountId(), 'p2');

    expect(File('${dir.path}/servers.json').existsSync(), isFalse);
    expect(File('${dir.path}/servers.json.migrated').existsSync(), isTrue);
    expect(File('${dir.path}/accounts.json.migrated').existsSync(), isTrue);
  });

  test('does nothing when the database already holds servers', () async {
    await servers.save(
      const JellyfinServer(
        id: 'existing',
        baseUrl: 'https://existing',
        name: 'Existing',
        reportedVersion: '10.11.6',
      ),
    );
    writeLegacy(
      serverRows: [
        {'id': 's9', 'baseUrl': 'https://x', 'name': 'X'},
      ],
    );

    await importer.run();

    expect((await servers.all()).map((s) => s.id), ['existing']);
    // Untouched, so a retry is still possible.
    expect(File('${dir.path}/servers.json').existsSync(), isTrue);
  });

  test('is a no-op when there are no legacy files', () async {
    await importer.run();
    expect(await servers.all(), isEmpty);
  });

  test(
    'ignores an unparseable active pointer but still imports rows',
    () async {
      writeLegacy(
        serverRows: [
          {'id': 's1', 'baseUrl': 'https://a', 'name': 'A'},
        ],
        accountRows: [
          {'id': 'p1', 'serverId': 's1', 'userId': 'u1', 'username': 'alice'},
        ],
        activeAccountId: 'not-a-real-account',
      );

      await importer.run();

      expect((await accounts.all()).map((a) => a.id), ['p1']);
      expect(await accounts.activeAccountId(), isNull);
    },
  );

  test(
    'survives a corrupt servers.json without importing partial data',
    () async {
      File('${dir.path}/servers.json').writeAsStringSync('{ not json');
      File(
        '${dir.path}/accounts.json',
      ).writeAsStringSync(jsonEncode({'accounts': const []}));

      await importer.run();

      expect(await servers.all(), isEmpty);
    },
  );
}
