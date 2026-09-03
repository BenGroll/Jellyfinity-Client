import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/persistence/json_store.dart';

import '../../support/test_logger.dart';

void main() {
  late Directory dir;
  late FileJsonStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('jellyfinity_store_test');
    store = FileJsonStore(() async => dir, TestLogger());
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('reads back what was written', () async {
    await store.write('servers', {
      'servers': [
        {'id': 'a', 'name': 'Home'},
      ],
    });

    final read = await store.read('servers');
    expect(read['servers'], hasLength(1));
    expect((read['servers'] as List).first['name'], 'Home');
  });

  test('an unwritten document reads as empty', () async {
    expect(await store.read('nothing'), isEmpty);
  });

  test('creates the directory on first write', () async {
    final missing = Directory('${dir.path}/nested/deep');
    final s = FileJsonStore(() async => missing, TestLogger());

    await s.write('doc', {'k': 'v'});

    expect(missing.existsSync(), isTrue);
    expect((await s.read('doc'))['k'], 'v');
  });

  test('a corrupt document degrades to empty instead of throwing', () async {
    File('${dir.path}/servers.json').writeAsStringSync('{not json');

    expect(await store.read('servers'), isEmpty);
  });

  test('a non-object document degrades to empty', () async {
    File('${dir.path}/servers.json').writeAsStringSync('[1, 2, 3]');

    expect(await store.read('servers'), isEmpty);
  });

  test('a later write replaces an earlier one', () async {
    await store.write('doc', {'v': 1});
    await store.write('doc', {'v': 2});

    expect((await store.read('doc'))['v'], 2);
  });

  test('serialised writes do not interleave', () async {
    await Future.wait([
      store.write('doc', {'v': 'first'}),
      store.write('doc', {'v': 'second'}),
    ]);

    // Whichever landed last, the file is a single valid document.
    final read = await store.read('doc');
    expect(read['v'], anyOf('first', 'second'));
  });

  test('delete removes a document', () async {
    await store.write('doc', {'v': 1});
    await store.delete('doc');

    expect(await store.read('doc'), isEmpty);
  });
}
