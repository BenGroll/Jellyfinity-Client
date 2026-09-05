import 'package:injectable/injectable.dart';

import '../../core/result/result.dart';
import '../../domain/downloads/LocalAudioSource.dart';
import '../../domain/media/MediaId.dart';
import '../../domain/playback/AudioSourceResolver.dart';
import '../../domain/playback/stream_quality.dart';

/// The [AudioSourceResolver] the application actually plays through: a
/// completed download first, the server second (v0.2.0).
///
/// A decorator rather than a change to `PlaybackCubit`, because
/// preferring a local file is not a playback rule — it is what
/// "downloaded" *means*. The queue, crossfade, normalization, failure
/// handling and availability semantics stay exactly as they were; the
/// only difference is the address a source resolves to. That is also
/// what makes a downloaded track playable with the server switched off:
/// nothing further up ever asks whether the server is reachable.
///
/// [StreamQuality] is deliberately ignored for a local file. A download
/// is a file that already exists at the quality it was fetched at, and
/// re-fetching it from the server because a *streaming* preference says
/// something else would defeat the point of having downloaded it. The
/// separate download-quality preference `ROADMAP.md` puts in v0.2.2 is
/// what governs the quality a file arrives at.
@LazySingleton(as: AudioSourceResolver)
class LocalFirstAudioSourceResolver implements AudioSourceResolver {
  LocalFirstAudioSourceResolver(
    @Named(remoteAudioSourceResolver) this._remote,
    this._local,
  );

  final AudioSourceResolver _remote;
  final LocalAudioSource _local;

  @override
  Future<Result<Uri>> resolve(
    MediaId id, {
    StreamQuality quality = StreamQuality.original,
  }) async {
    final local = await _local.addressFor(id);
    if (local != null) return Result.ok(local);
    return _remote.resolve(id, quality: quality);
  }
}
