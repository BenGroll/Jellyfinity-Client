import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/infrastructure/downloads/DownloadStorage.dart';

const _id = MediaId(serverId: 'server-1', itemId: 'track-1');

void main() {
  late Directory root;
  late DownloadStorage storage;

  setUp(() {
    root = Directory.systemTemp.createTempSync('jellyfinity_downloads_test_');
    storage = DownloadStorage(rootDirectory: () async => root);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('has no completed file before anything is written', () async {
    expect(await storage.completedFile(_id), isNull);
  });

  test('completing a partial transfer makes it the completed file', () async {
    final partial = await storage.partialFile(_id);
    await partial.writeAsBytes([1, 2, 3]);

    final completed = await storage.complete(_id, partial, extension: 'flac');

    expect(completed.path, endsWith('audio.flac'));
    expect(await completed.readAsBytes(), [1, 2, 3]);
    // The rename is what makes completion atomic: a caller can only ever
    // observe "not there" or "the whole file", never a half-written one
    // under the completed name.
    expect(await partial.exists(), isFalse);
    expect((await storage.completedFile(_id))?.path, completed.path);
  });

  test('completing again replaces the earlier file (a re-download)', () async {
    final first = await storage.partialFile(_id);
    await first.writeAsBytes([1]);
    await storage.complete(_id, first, extension: 'mp3');

    final second = await storage.partialFile(_id);
    await second.writeAsBytes([2, 2]);
    final completed = await storage.complete(_id, second, extension: 'flac');

    final files = await storage
        .directoryFor(_id)
        .then((dir) => dir.list().toList());
    // Only the new file remains — no stray mp3 left beside the flac.
    expect(files.length, 1);
    expect(await completed.readAsBytes(), [2, 2]);
  });

  test('discard removes both a partial and a completed file', () async {
    final partial = await storage.partialFile(_id);
    await partial.writeAsBytes([1]);
    await storage.complete(_id, partial, extension: 'flac');

    await storage.discard(_id);

    expect(await storage.completedFile(_id), isNull);
    expect(await (await storage.partialFile(_id)).exists(), isFalse);
  });

  test('discard on an id nothing was ever stored for is a no-op', () async {
    await storage.discard(_id);
    expect(await storage.completedFile(_id), isNull);
  });

  test('two ids never share a directory', () async {
    const other = MediaId(serverId: 'server-1', itemId: 'track-2');
    final partial = await storage.partialFile(_id);
    await partial.writeAsBytes([9]);
    await storage.complete(_id, partial, extension: 'flac');

    expect(await storage.completedFile(other), isNull);
  });
}
