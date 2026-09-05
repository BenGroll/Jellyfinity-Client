import 'package:injectable/injectable.dart';

import '../../../core/result/result.dart';
import '../../../domain/media/MediaId.dart';
import '../../../domain/playback/Lyrics.dart';
import '../../../domain/playback/LyricsResolver.dart';
import 'jellyfin_media_api.dart';
import 'LyricsDto.dart';

/// [LyricsResolver] over the active session's Jellyfin server.
///
/// Same scope/fetch/map shape as [JellyfinTrackSourceInfoResolver], reading
/// [JellyfinMediaApi.lyrics] instead of the items endpoint.
@LazySingleton(as: LyricsResolver)
class JellyfinLyricsResolver implements LyricsResolver {
  JellyfinLyricsResolver(this._api);

  final JellyfinMediaApi _api;

  @override
  Future<Result<Lyrics?>> resolve(MediaId id) async {
    final scope = _api.scopeFor(id);
    if (scope case Err<MediaScope>(:final failure)) return Result.err(failure);
    final (:mapper, :itemId) = (scope as Ok<MediaScope>).value;

    final response = await _api.lyrics(itemId);
    if (response case Err<LyricsDto?>(:final failure)) {
      return Result.err(failure);
    }

    final dto = (response as Ok<LyricsDto?>).value;
    return Result.ok(dto == null ? null : mapper.toLyrics(dto));
  }
}
