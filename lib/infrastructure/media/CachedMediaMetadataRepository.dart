import 'package:injectable/injectable.dart';

import '../../core/result/result.dart';
import '../../domain/media/media.dart';
import '../jellyfin/media/JellyfinMediaMetadataRepository.dart';
import '../persistence/media/media_cache_store.dart';
import 'cache_fallback.dart';

/// [MediaMetadataRepository] with the local copy behind the server.
///
/// This is the contract everything that starts from an id uses — a deep
/// link, a playlist header, later a restored queue entry — so it is
/// exactly where an unreachable server would otherwise turn a saved
/// library into a dead end.
@LazySingleton(as: MediaMetadataRepository)
class CachedMediaMetadataRepository implements MediaMetadataRepository {
  CachedMediaMetadataRepository(this._remote, this._cache);

  final JellyfinMediaMetadataRepository _remote;
  final MediaCacheStore _cache;

  @override
  Future<Result<MediaItem>> item(MediaId id) async {
    final result = await _remote.item(id);

    switch (result) {
      case Ok<MediaItem>(:final value):
        await _cache.saveItem(value);
        return result;
      case Err<MediaItem>(:final failure):
        if (!canServeFromCache(failure)) return result;
        final saved = await _cache.readItem(id);
        return saved == null ? result : Result.ok(saved);
    }
  }
}
