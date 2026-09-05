import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../domain/downloads/DownloadEngine.dart';
import '../../domain/media/MediaId.dart';
import '../jellyfin/http/TransportErrorMapper.dart';
import 'DownloadStorage.dart';

/// [DownloadEngine] that streams a file over HTTP into [DownloadStorage]
/// while the app is running (ADR-0020).
///
/// ## Why this and not a platform background-transfer worker
///
/// `ROADMAP.md` is explicit that a background-transfer dependency may
/// only be adopted "after an Android+iOS resume/cancellation proof of
/// behavior", and allows "a documented foreground-only implementation"
/// when that proof cannot be produced. That is what this is. Everything
/// the roadmap asks a download seam to do — resume, cancel, retry,
/// atomic completion, stale-session failure, partial cleanup — is
/// implemented and tested here; what it does *not* do is keep
/// transferring after the OS suspends the process. It survives that
/// case rather than losing work: the partial file and its record both
/// persist, and the transfer resumes from the byte it stopped at.
///
/// Replacing this with an OS worker is a matter of writing another
/// [DownloadEngine]; nothing above the interface changes.
///
/// ## Resuming
///
/// A transfer appends to `audio.part` and asks for the rest with a
/// `Range` header. A server that ignores the range (answering `200`
/// where `206` was asked for) makes Jellyfinity start the file over
/// rather than append to bytes it already has — a duplicated prefix
/// would produce a file that looks complete and plays as noise.
///
/// ## Its own `Dio`
///
/// Not `JellyfinHttpClient`: that client is built per server around JSON
/// requests, and its retry interceptor would replay a partially consumed
/// byte stream. The stream address already carries its own credential as
/// a query parameter (see `JellyfinAudioSourceResolver`), so no
/// interceptor is needed to authenticate one.
@LazySingleton(as: DownloadEngine)
class HttpDownloadEngine implements DownloadEngine {
  HttpDownloadEngine(this._storage, {Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 20)
      // Between chunks, not for the whole file: a large album track over
      // a slow connection is normal, a stalled socket is not.
      ..receiveTimeout = const Duration(seconds: 60)
      ..followRedirects = true;
  }

  /// The constructor the composition root uses. `dio` is a test seam,
  /// not a dependency: there is no shared `Dio` to inject, because this
  /// engine deliberately does not go through `JellyfinHttpClient`.
  @factoryMethod
  factory HttpDownloadEngine.create(DownloadStorage storage) =>
      HttpDownloadEngine(storage);

  final DownloadStorage _storage;
  final Dio _dio;
  final TransportErrorMapper _errorMapper = const TransportErrorMapper();

  /// The cancel token of each transfer currently running, so [abort] can
  /// reach one. At most one entry today (`DownloadsCubit` runs downloads
  /// one at a time), but keyed by id so a future parallel engine needs
  /// no change here.
  final Map<MediaId, CancelToken> _inFlight = {};

  /// Progress is reported at most this often, so a fast transfer does
  /// not rebuild a progress ring hundreds of times a second.
  static const Duration _progressInterval = Duration(milliseconds: 200);

  @override
  Future<Result<StoredDownload>> fetch(
    MediaId id,
    Uri source, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    final cancelToken = CancelToken();
    _inFlight[id] = cancelToken;
    try {
      return await _fetch(id, source, cancelToken, onProgress);
    } on FileSystemException catch (error, stackTrace) {
      return Result.err(_mapFileSystem(error, stackTrace));
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'The download did not finish.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      _inFlight.remove(id);
    }
  }

  Future<Result<StoredDownload>> _fetch(
    MediaId id,
    Uri source,
    CancelToken cancelToken,
    void Function(DownloadProgress progress)? onProgress,
  ) async {
    var partial = await _storage.partialFile(id);
    var offset = await partial.exists() ? await partial.length() : 0;

    final Response<ResponseBody> response;
    try {
      response = await _dio.getUri<ResponseBody>(
        source,
        options: Options(
          responseType: ResponseType.stream,
          headers: offset > 0
              ? {HttpHeaders.rangeHeader: 'bytes=$offset-'}
              : null,
          validateStatus: (status) => status == 200 || status == 206,
        ),
        cancelToken: cancelToken,
      );
    } catch (error, stackTrace) {
      return Result.err(_errorMapper.map(error, stackTrace));
    }

    if (offset > 0 && response.statusCode != HttpStatus.partialContent) {
      // The server sent the whole file back. Start over rather than
      // append a second copy of the bytes already on disk.
      if (await partial.exists()) await partial.delete();
      partial = await _storage.partialFile(id);
      offset = 0;
    }

    final totalBytes = _totalBytes(response, offset);
    var receivedBytes = offset;
    onProgress?.call((receivedBytes: receivedBytes, totalBytes: totalBytes));

    final sink = partial.openWrite(mode: FileMode.append);
    var lastReport = DateTime.now();
    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastReport) >= _progressInterval) {
          lastReport = now;
          onProgress?.call((
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ));
        }
      }
      await sink.flush();
      await sink.close();
    } catch (error, stackTrace) {
      // Close without letting a second failure hide the first; whatever
      // reached the disk stays there for the next attempt to resume from.
      try {
        await sink.close();
      } on Object {
        // Already failing; the original error is the one worth reporting.
      }
      if (error is FileSystemException) {
        return Result.err(_mapFileSystem(error, stackTrace));
      }
      return Result.err(_errorMapper.map(error, stackTrace));
    }

    final completed = await _storage.complete(
      id,
      partial,
      extension: _extensionFor(response, source),
    );
    final byteCount = await completed.length();
    onProgress?.call((receivedBytes: byteCount, totalBytes: byteCount));
    return Result.ok(
      StoredDownload(address: completed.uri, byteCount: byteCount),
    );
  }

  @override
  Future<void> abort(MediaId id) async {
    _inFlight.remove(id)?.cancel('Download stopped.');
  }

  @override
  Future<void> discard(MediaId id) async {
    await abort(id);
    await _storage.discard(id);
  }

  @override
  Future<Uri?> locate(MediaId id) async =>
      (await _storage.completedFile(id))?.uri;

  @override
  Future<int> partialByteCount(MediaId id) async {
    final partial = await _storage.partialFile(id);
    return await partial.exists() ? partial.length() : 0;
  }

  /// The file's full size, preferring `Content-Range`'s total (which is
  /// the whole file) over `Content-Length` (which, for a resumed
  /// transfer, is only the part still to come).
  int? _totalBytes(Response<Object?> response, int offset) {
    final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange != null) {
      final slash = contentRange.lastIndexOf('/');
      if (slash >= 0) {
        final total = int.tryParse(contentRange.substring(slash + 1).trim());
        if (total != null && total > 0) return total;
      }
    }
    final length = int.tryParse(
      response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
    );
    return length == null ? null : offset + length;
  }

  /// What to call the finished file.
  ///
  /// The server's own content type first, then the address's extension.
  /// Neither is guaranteed, so there is a last-resort name — a file
  /// Android will sniff correctly and iOS may not, which is honest about
  /// what is actually known rather than guessing a codec.
  String _extensionFor(Response<Object?> response, Uri source) {
    final contentType = response.headers
        .value(HttpHeaders.contentTypeHeader)
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    final known = _extensionsByContentType[contentType];
    if (known != null) return known;

    final path = source.path;
    final dot = path.lastIndexOf('.');
    if (dot > 0 && dot < path.length - 1) {
      final extension = path.substring(dot + 1).toLowerCase();
      if (extension.length <= 5 && RegExp(r'^[a-z0-9]+$').hasMatch(extension)) {
        return extension;
      }
    }
    return 'audio';
  }

  static const Map<String, String> _extensionsByContentType = {
    'audio/flac': 'flac',
    'audio/x-flac': 'flac',
    'audio/mpeg': 'mp3',
    'audio/mp3': 'mp3',
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
    'audio/aac': 'aac',
    'audio/ogg': 'ogg',
    'application/ogg': 'ogg',
    'audio/opus': 'opus',
    'audio/wav': 'wav',
    'audio/x-wav': 'wav',
    'audio/wave': 'wav',
    'audio/aiff': 'aiff',
    'audio/x-aiff': 'aiff',
    'audio/webm': 'webm',
    'audio/x-ms-wma': 'wma',
  };

  /// Running out of room is its own answer to the user ("free some up"),
  /// so it does not get collapsed into a generic write failure that
  /// offers a retry which cannot succeed. `ENOSPC` is 28 on both Android
  /// and iOS.
  Failure _mapFileSystem(FileSystemException error, StackTrace stackTrace) {
    if (error.osError?.errorCode == _noSpaceLeftErrno) {
      return InsufficientStorageFailure(
        'There is not enough storage left on this device.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    // Kept as the cause rather than flattened into the message:
    // `DownloadsCubit` reads it to tell a storage problem apart from a
    // server one, which are two different things to ask the user to fix.
    return UnexpectedFailure(
      'The download could not be saved to this device.',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static const int _noSpaceLeftErrno = 28;
}
