import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/session/jellyfin_server.dart';
import 'package:jellyfinity/infrastructure/persistence/database/app_database.dart';
import 'package:jellyfinity/infrastructure/persistence/drift_server_registry.dart';

import '../../support/test_database.dart';

JellyfinServer _server(
  String id, {
  String baseUrl = 'https://jf.example',
  String name = 'Home',
}) => JellyfinServer(
  id: id,
  baseUrl: baseUrl,
  name: name,
  reportedVersion: '10.11.6',
  serverId: 'srv-$id',
);

void main() {
  late AppDatabase db;
  late DriftServerRegistry registry;

  setUp(() {
    db = newTestDatabase();
    registry = DriftServerRegistry(db);
  });
  tearDown(() => db.close());

  test('starts empty', () async {
    expect(await registry.all(), isEmpty);
  });

  test('saves and reads a server back by id and base url', () async {
    await registry.save(_server('a'));

    expect((await registry.byId('a'))?.name, 'Home');
    expect((await registry.byBaseUrl('https://jf.example'))?.id, 'a');
    expect(await registry.byId('missing'), isNull);
  });

  test('all() returns servers in the order they were first saved', () async {
    await registry.save(_server('a', baseUrl: 'https://a'));
    await registry.save(_server('b', baseUrl: 'https://b'));
    await registry.save(_server('c', baseUrl: 'https://c'));

    expect((await registry.all()).map((s) => s.id), ['a', 'b', 'c']);
  });

  test(
    'save() on an existing id updates in place without reordering',
    () async {
      await registry.save(_server('a', baseUrl: 'https://a'));
      await registry.save(_server('b', baseUrl: 'https://b'));

      await registry.save(_server('a', baseUrl: 'https://a', name: 'Renamed'));

      final all = await registry.all();
      expect(all.map((s) => s.id), ['a', 'b']);
      expect(all.first.name, 'Renamed');
    },
  );

  test('remove() deletes only the target server', () async {
    await registry.save(_server('a', baseUrl: 'https://a'));
    await registry.save(_server('b', baseUrl: 'https://b'));

    await registry.remove('a');

    expect((await registry.all()).map((s) => s.id), ['b']);
    await registry.remove('missing'); // no-op, no throw
  });
}
