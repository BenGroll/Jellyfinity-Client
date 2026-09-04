import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/media.dart';
import 'base_item_dto.dart';
import 'jellyfin_media_api.dart';

/// [MediaMetadataRepository] backed by the active session's Jellyfin
/// server.
@LazySingleton(as: MediaMetadataRepository)
class JellyfinMediaMetadataRepository implements MediaMetadataRepository {
  JellyfinMediaMetadataRepository(this._api);

  final JellyfinMediaApi _api;

  @override
  Future<Result<MediaItem>> item(MediaId id) async {
    final scope = _api.scopeFor(id);
    if (scope case Err<MediaScope>(:final failure)) return Result.err(failure);
    final (:mapper, :itemId) = (scope as Ok<MediaScope>).value;

    final response = await _api.item(itemId);
    if (response case Err<BaseItemDto?>(:final failure)) {
      return Result.err(failure);
    }

    final dto = (response as Ok<BaseItemDto?>).value;
    final item = dto == null ? null : mapper.toMediaItem(dto);
    if (item == null) {
      // Removed from the library, or a kind of item Jellyfinity does not
      // present. Both are a link that goes nowhere.
      return const Result.err(
        UnavailableFailure('That item is no longer in your library.'),
      );
    }
    return Result.ok(item);
  }
}
