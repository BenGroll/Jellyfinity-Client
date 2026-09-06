import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/downloads/DownloadEngine.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/infrastructure/downloads/DownloadStorage.dart';
import 'package:jellyfinity/infrastructure/downloads/HttpDownloadEngine.dart';

import '../../support/FakeDioAdapter.dart';

const _id = MediaId(serverId: 'server-1', itemId: 'track-1');
final _source = Uri.parse('https://media.example.test/Audio/track-1/stream');

/// The same track at a transcoded download quality — a different address
/// answering with different bytes, as `JellyfinAudioSourceResolver`
/// builds it.
final _transcoded = Uri.parse(
  'https://media.example.test/Audio/track-1/stream.aac'
  '?audioCodec=aac&audioBitRate=256000',
);

/// [_source] carrying a session token, the one part of a stream address
/// that changes without changing a byte of the audio.
Uri _authorized(String token) =>
    _source.replace(queryParameters: {'api_key': token, 'static': 'true'});

/// A [ResponseBody] over fixed bytes, with headers a real server would
/// send for a full (`200`) or partial (`206`) audio response.
ResponseBody _audioResponse(
  List<int> bytes, {
  int statusCode = 200,
  int? rangeStart,
  int? totalLength,
}) {
  final headers = <String, List<String>>{
    Headers.contentTypeHeader: ['audio/flac'],
    Headers.contentLengthHeader: ['${bytes.length}'],
  };
  if (rangeStart != null) {
    final total = totalLength ?? (rangeStart + bytes.length);
    headers[HttpHeaders.contentRangeHeader] = [
      'bytes $rangeStart-${rangeStart + bytes.length - 1}/$total',
    ];
  }
  return ResponseBody(
    Stream.value(Uint8List.fromList(bytes)),
    statusCode,
    headers: headers,
  );
}

/// Seeds a partial file exactly as an interrupted transfer of [source]
/// would have left it: the bytes, plus the marker recording what they are
/// of. Writing bytes without the marker is a different case — see the
/// "unmarked partial" test.
Future<void> _seedPartial(
  DownloadStorage storage,
  List<int> bytes, {
  Uri? source,
}) async {
  final partial = await storage.partialFileForSource(
    _id,
    HttpDownloadEngine.sourceKeyFor(source ?? _source),
  );
  await partial.writeAsBytes(bytes);
}

HttpDownloadEngine _engine(DownloadStorage storage, FakeDioAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return HttpDownloadEngine(storage, dio: dio);
}

void main() {
  late Directory root;
  late DownloadStorage storage;

  setUp(() {
    root = Directory.systemTemp.createTempSync('jellyfinity_engine_test_');
    storage = DownloadStorage(rootDirectory: () async => root);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('fetches a whole file and completes it atomically', () async {
    final adapter = FakeDioAdapter((_) async => _audioResponse([1, 2, 3, 4]));
    final engine = _engine(storage, adapter);

    final result = await engine.fetch(_id, _source);

    expect(result.isOk, isTrue);
    final stored = result.valueOrNull!;
    expect(stored.byteCount, 4);
    expect(stored.address.path, endsWith('.flac'));
    expect(await engine.locate(_id), stored.address);
    expect(await engine.partialByteCount(_id), 0);
  });

  test('reports progress as bytes arrive', () async {
    final updates = <DownloadProgress>[];
    final adapter = FakeDioAdapter(
      (_) async => _audioResponse([1, 2, 3, 4, 5]),
    );
    final engine = _engine(storage, adapter);

    await engine.fetch(_id, _source, onProgress: updates.add);

    expect(updates, isNotEmpty);
    expect(updates.last.receivedBytes, 5);
    expect(updates.last.totalBytes, 5);
  });

  test('resumes a partial transfer with a Range request', () async {
    await _seedPartial(storage, [1, 2]);

    RequestOptions? seenRequest;
    final adapter = FakeDioAdapter((options) async {
      seenRequest = options;
      return _audioResponse([3, 4], statusCode: 206, rangeStart: 2);
    });
    final engine = _engine(storage, adapter);

    final result = await engine.fetch(_id, _source);

    expect(seenRequest!.headers[HttpHeaders.rangeHeader], 'bytes=2-');
    final stored = result.valueOrNull!;
    expect(stored.byteCount, 4);
    expect(await File.fromUri(stored.address).readAsBytes(), [1, 2, 3, 4]);
  });

  test('starts over when the server ignores the range and sends 200', () async {
    await _seedPartial(storage, [9, 9]);

    final adapter = FakeDioAdapter(
      (_) async => _audioResponse([1, 2, 3], statusCode: 200),
    );
    final engine = _engine(storage, adapter);

    final result = await engine.fetch(_id, _source);

    // The old bytes are gone, not prefixed onto the new ones — a
    // duplicated prefix would be silent corruption.
    final stored = result.valueOrNull!;
    expect(await File.fromUri(stored.address).readAsBytes(), [1, 2, 3]);
  });

  group('a partial only resumes onto the address it came from', () {
    test('starts over when the download quality changed under it', () async {
      // Paused at original quality, retried after the download-quality
      // preference moved to a transcode: a different encoding, so the
      // bytes already on disk are not the head of this file. Appending to
      // them would complete a download that plays as noise.
      await _seedPartial(storage, [9, 9]);

      RequestOptions? seenRequest;
      final adapter = FakeDioAdapter((options) async {
        seenRequest = options;
        return _audioResponse([1, 2, 3]);
      });

      final result = await _engine(storage, adapter).fetch(_id, _transcoded);

      expect(seenRequest!.headers[HttpHeaders.rangeHeader], isNull);
      final stored = result.valueOrNull!;
      expect(await File.fromUri(stored.address).readAsBytes(), [1, 2, 3]);
    });

    test('resumes across a new session token', () async {
      // The same address bar its `api_key`: a re-issued session token
      // changes the URL without changing a byte of the audio, so throwing
      // the partial away there would be needless re-downloading.
      await _seedPartial(storage, [1, 2], source: _authorized('token-one'));

      RequestOptions? seenRequest;
      final adapter = FakeDioAdapter((options) async {
        seenRequest = options;
        return _audioResponse([3, 4], statusCode: 206, rangeStart: 2);
      });

      final result = await _engine(
        storage,
        adapter,
      ).fetch(_id, _authorized('token-two'));

      expect(seenRequest!.headers[HttpHeaders.rangeHeader], 'bytes=2-');
      expect(await File.fromUri(result.valueOrNull!.address).readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
    });

    test('discards a partial left with no record of its source', () async {
      // Everything an install downloaded before this guard existed. The
      // bytes cannot be vouched for, so one track starts over rather than
      // risking a spliced file; it self-heals in a single transfer.
      final partial = await storage.partialFile(_id);
      await partial.writeAsBytes([9, 9]);

      RequestOptions? seenRequest;
      final adapter = FakeDioAdapter((options) async {
        seenRequest = options;
        return _audioResponse([1, 2, 3]);
      });

      final result = await _engine(storage, adapter).fetch(_id, _source);

      expect(seenRequest!.headers[HttpHeaders.rangeHeader], isNull);
      expect(await File.fromUri(result.valueOrNull!.address).readAsBytes(), [
        1,
        2,
        3,
      ]);
    });

    test('the source key ignores the credential but not the quality', () {
      expect(
        HttpDownloadEngine.sourceKeyFor(_authorized('token-one')),
        HttpDownloadEngine.sourceKeyFor(_authorized('token-two')),
      );
      expect(
        HttpDownloadEngine.sourceKeyFor(_source),
        isNot(HttpDownloadEngine.sourceKeyFor(_transcoded)),
      );
      expect(
        HttpDownloadEngine.sourceKeyFor(_authorized('token-one')),
        isNot(contains('token-one')),
      );
    });
  });

  test('abort keeps the partial bytes for a later resume', () async {
    final gate = Completer<void>();
    final controller = StreamController<Uint8List>();
    final adapter = FakeDioAdapter((_) async {
      unawaited(
        Future(() async {
          controller.add(Uint8List.fromList([1, 2]));
          await gate.future;
          await controller.close();
        }),
      );
      return ResponseBody(
        controller.stream,
        200,
        headers: {
          Headers.contentTypeHeader: ['audio/flac'],
        },
      );
    });
    final engine = _engine(storage, adapter);

    final future = engine.fetch(_id, _source);
    // Give the stream a moment to deliver its first chunk before
    // aborting.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await engine.abort(_id);
    gate.complete();
    await future;

    expect(await engine.locate(_id), isNull);
    expect(await engine.partialByteCount(_id), greaterThan(0));
  });

  test('discard removes a partial transfer entirely', () async {
    final partial = await storage.partialFile(_id);
    await partial.writeAsBytes([1, 2, 3]);

    final adapter = FakeDioAdapter((_) async => _audioResponse([]));
    await _engine(storage, adapter).discard(_id);

    expect(await storage.completedFile(_id), isNull);
    expect(await (await storage.partialFile(_id)).exists(), isFalse);
  });

  test('a connection failure comes back as a Result, never a throw', () async {
    final adapter = FakeDioAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final engine = _engine(storage, adapter);

    final result = await engine.fetch(_id, _source);

    expect(result.isErr, isTrue);
    expect(result.failureOrNull, isA<RecoverableFailure>());
  });

  test('a broken write comes back as a typed failure, not a throw', () async {
    // A file sits where DownloadStorage needs a "downloads" directory,
    // so every write beneath it fails. ENOSPC itself is not portable to
    // simulate; this proves the general write-failure path is caught and
    // normalized rather than escaping — the errno-specific branch is
    // exercised by construction (see HttpDownloadEngine._mapFileSystem).
    File('${root.path}/downloads').createSync();
    final adapter = FakeDioAdapter((_) async => _audioResponse([1, 2, 3]));
    final engine = _engine(storage, adapter);

    final result = await engine.fetch(_id, _source);

    expect(result.isErr, isTrue);
    expect(result.failureOrNull, isA<UnexpectedFailure>());
  });
}
