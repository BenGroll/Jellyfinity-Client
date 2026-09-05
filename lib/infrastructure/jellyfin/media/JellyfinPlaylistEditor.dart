import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/media.dart';
import 'jellyfin_media_api.dart';

/// [PlaylistEditor] backed by the active session's Jellyfin server.
///
/// Every mutation writes straight through to Jellyfin (ADR-0016) — there
/// is no local optimistic copy to reconcile, and nothing here is cached.
@LazySingleton(as: PlaylistEditor)
class JellyfinPlaylistEditor implements PlaylistEditor {
  JellyfinPlaylistEditor(this._api);

  final JellyfinMediaApi _api;

  @override
  Future<Result<MediaId>> create({
    required String name,
    List<MediaId> trackIds = const [],
  }) async {
    final serverId = _api.serverId;
    if (serverId == null) {
      return const Result.err(
        UnauthorizedFailure('Sign in to create a playlist.'),
      );
    }

    final ids = _localIds(trackIds);
    if (ids case Err<List<String>>(:final failure)) return Result.err(failure);

    final response = await _api.createPlaylist(
      name: name,
      ids: (ids as Ok<List<String>>).value,
    );
    return response.map((itemId) => MediaId(serverId: serverId, itemId: itemId));
  }

  @override
  Future<Result<void>> rename(MediaId playlistId, String name) async {
    final itemId = _api.localItemId(playlistId);
    if (itemId case Err<String>(:final failure)) return Result.err(failure);
    return _api.renamePlaylist((itemId as Ok<String>).value, name);
  }

  @override
  Future<Result<void>> delete(MediaId playlistId) async {
    final itemId = _api.localItemId(playlistId);
    if (itemId case Err<String>(:final failure)) return Result.err(failure);
    return _api.deleteItem((itemId as Ok<String>).value);
  }

  @override
  Future<Result<void>> addTracks(
    MediaId playlistId,
    List<MediaId> trackIds,
  ) async {
    if (trackIds.isEmpty) return const Result.ok(null);

    final playlistItemId = _api.localItemId(playlistId);
    if (playlistItemId case Err<String>(:final failure)) {
      return Result.err(failure);
    }

    final ids = _localIds(trackIds);
    if (ids case Err<List<String>>(:final failure)) return Result.err(failure);

    return _api.addPlaylistItems(
      (playlistItemId as Ok<String>).value,
      (ids as Ok<List<String>>).value,
    );
  }

  @override
  Future<Result<void>> removeEntries(
    MediaId playlistId,
    List<String> entryIds,
  ) async {
    if (entryIds.isEmpty) return const Result.ok(null);
    final itemId = _api.localItemId(playlistId);
    if (itemId case Err<String>(:final failure)) return Result.err(failure);
    return _api.removePlaylistItems((itemId as Ok<String>).value, entryIds);
  }

  @override
  Future<Result<void>> moveEntry(
    MediaId playlistId, {
    required String entryId,
    required int newIndex,
  }) async {
    final itemId = _api.localItemId(playlistId);
    if (itemId case Err<String>(:final failure)) return Result.err(failure);
    return _api.movePlaylistItem(
      (itemId as Ok<String>).value,
      entryId,
      newIndex,
    );
  }

  /// Every id in [trackIds], resolved to its item id on the active
  /// server — or the first failure, the same short-circuit
  /// `JellyfinPlaylistRepository` uses for a single id.
  Result<List<String>> _localIds(List<MediaId> trackIds) {
    final ids = <String>[];
    for (final id in trackIds) {
      final local = _api.localItemId(id);
      if (local case Err<String>(:final failure)) return Result.err(failure);
      ids.add((local as Ok<String>).value);
    }
    return Result.ok(ids);
  }
}
