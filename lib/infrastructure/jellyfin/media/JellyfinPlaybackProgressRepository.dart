import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/media.dart';
import 'base_item_dto.dart';
import 'jellyfin_media_api.dart';

/// [PlaybackProgressRepository] backed by the active session's Jellyfin
/// server.
///
/// Reads the played flag and resume position the server keeps for the
/// signed-in user, can set or clear the flag, and (since v0.0.9) reports
/// a live playback session — start, periodic progress, and stop — so
/// Jellyfin's own resume/played tracking agrees with what Jellyfinity
/// actually played.
@LazySingleton(as: PlaybackProgressRepository)
class JellyfinPlaybackProgressRepository implements PlaybackProgressRepository {
  JellyfinPlaybackProgressRepository(this._api);

  final JellyfinMediaApi _api;

  @override
  Future<Result<PlaybackProgress>> forItem(MediaId id) async {
    final scope = _api.scopeFor(id);
    if (scope case Err<MediaScope>(:final failure)) return Result.err(failure);
    final (:mapper, :itemId) = (scope as Ok<MediaScope>).value;

    final response = await _api.item(itemId);
    if (response case Err<BaseItemDto?>(:final failure)) {
      return Result.err(failure);
    }

    final dto = (response as Ok<BaseItemDto?>).value;
    if (dto == null) {
      return const Result.err(
        UnavailableFailure('That item is no longer in your library.'),
      );
    }
    return Result.ok(mapper.toProgress(dto.userData));
  }

  @override
  Future<Result<void>> markPlayed(MediaId id) => _setPlayed(id, played: true);

  @override
  Future<Result<void>> markUnplayed(MediaId id) =>
      _setPlayed(id, played: false);

  Future<Result<void>> _setPlayed(MediaId id, {required bool played}) async {
    final itemId = _api.localItemId(id);
    if (itemId case Err<String>(:final failure)) return Result.err(failure);
    return _api.setPlayed((itemId as Ok<String>).value, played: played);
  }

  @override
  Future<Result<void>> reportStart(MediaId id) =>
      _report(id, (itemId) => _api.reportPlaybackStart(itemId));

  @override
  Future<Result<void>> reportProgress(
    MediaId id, {
    required Duration position,
    required bool isPaused,
  }) {
    return _report(
      id,
      (itemId) => _api.reportPlaybackProgress(
        itemId,
        position: position,
        isPaused: isPaused,
      ),
    );
  }

  @override
  Future<Result<void>> reportStop(MediaId id, {required Duration position}) {
    return _report(
      id,
      (itemId) => _api.reportPlaybackStopped(itemId, position: position),
    );
  }

  Future<Result<void>> _report(
    MediaId id,
    Future<Result<void>> Function(String itemId) call,
  ) async {
    final itemId = _api.localItemId(id);
    if (itemId case Err<String>(:final failure)) return Result.err(failure);
    return call((itemId as Ok<String>).value);
  }
}
