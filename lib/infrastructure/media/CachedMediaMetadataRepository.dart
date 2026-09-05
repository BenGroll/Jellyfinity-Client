import 'package:injectable/injectable.dart';

import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../domain/connectivity/OfflineMode.dart';
import '../../domain/media/media.dart';
import '../downloads/DownloadsLibrarySource.dart';
import '../jellyfin/media/JellyfinMediaMetadataRepository.dart';
import '../persistence/media/media_cache_store.dart';
import 'cache_fallback.dart';

/// [MediaMetadataRepository] with the local copy behind the server.
///
/// This is the contract everything that starts from an id uses — a deep
/// link, a playlist header, later a restored queue entry — so it is
/// exactly where an unreachable server would otherwise turn a saved
/// library into a dead end.
///
/// Working offline (v0.2.3) it short-circuits to that saved copy without
/// the round-trip, and when even the cache has nothing it asks the
/// profile's downloads: a playlist, album or artist that was downloaded
/// but never browsed still has an identity to render.
@LazySingleton(as: MediaMetadataRepository)
class CachedMediaMetadataRepository implements MediaMetadataRepository {
  CachedMediaMetadataRepository(
    this._remote,
    this._cache,
    this._offline,
    this._downloads,
  );

  final JellyfinMediaMetadataRepository _remote;
  final MediaCacheStore _cache;
  final OfflineMode _offline;
  final DownloadsLibrarySource _downloads;

  @override
  Future<Result<MediaItem>> item(MediaId id) async {
    final result = _offline.status.isOffline
        ? const Result<MediaItem>.err(RecoverableFailure('You are offline.'))
        : await _remote.item(id);

    switch (result) {
      case Ok<MediaItem>(:final value):
        await _cache.saveItem(value);
        return result;
      case Err<MediaItem>(:final failure):
        if (!canServeFromCache(failure)) return result;
        final saved = await _cache.readItem(id);
        if (saved != null) return Result.ok(saved);
        return await _fromDownloads(id) ?? result;
    }
  }

  /// A downloaded collection's stored identity, tried playlist-first (the
  /// only kind [item] is normally asked for), then album, then artist.
  Future<Result<MediaItem>?> _fromDownloads(MediaId id) async {
    for (final read in [
      _downloads.playlist,
      _downloads.album,
      _downloads.artist,
    ]) {
      final derived = await read(id);
      if (derived case Ok<MediaItem>(:final value)) return Result.ok(value);
    }
    return null;
  }
}
