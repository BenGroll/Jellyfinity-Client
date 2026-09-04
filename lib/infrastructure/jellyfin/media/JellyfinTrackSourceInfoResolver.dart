import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/MediaId.dart';
import '../../../domain/playback/TrackSourceInfo.dart';
import '../../../domain/playback/TrackSourceInfoResolver.dart';
import 'base_item_dto.dart';
import 'jellyfin_media_api.dart';

/// [TrackSourceInfoResolver] over the active session's Jellyfin server.
///
/// Same scope/fetch/map shape `JellyfinMusicLibraryRepository._single`
/// uses for one item, but asks for [JellyfinMediaApi.trackSourceFields]
/// instead of [JellyfinMediaApi.detailFields] — the one caller of this
/// class (Now Playing) needs a track's file details, not its overview or
/// child count.
@LazySingleton(as: TrackSourceInfoResolver)
class JellyfinTrackSourceInfoResolver implements TrackSourceInfoResolver {
  JellyfinTrackSourceInfoResolver(this._api);

  final JellyfinMediaApi _api;

  @override
  Future<Result<TrackSourceInfo>> resolve(MediaId id) async {
    final scope = _api.scopeFor(id);
    if (scope case Err<MediaScope>(:final failure)) return Result.err(failure);
    final (:mapper, :itemId) = (scope as Ok<MediaScope>).value;

    final response = await _api.item(
      itemId,
      fields: JellyfinMediaApi.trackSourceFields,
    );
    if (response case Err<BaseItemDto?>(:final failure)) {
      return Result.err(failure);
    }

    final dto = (response as Ok<BaseItemDto?>).value;
    final info = dto == null ? null : mapper.toTrackSourceInfo(dto);
    if (info == null) {
      return const Result.err(
        UnavailableFailure('Source details are unavailable.'),
      );
    }
    return Result.ok(info);
  }
}
