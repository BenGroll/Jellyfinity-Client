import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/MediaId.dart';
import '../../../domain/playback/AudioSourceResolver.dart';
import '../../../domain/playback/stream_quality.dart';
import '../identity/auth_token_provider.dart';
import '../identity/JellyfinSessionContext.dart';

/// [AudioSourceResolver] over the active session's Jellyfin server.
///
/// Builds the stream address for [id] at the requested [StreamQuality]
/// (ADR-0015): `static=true` for [StreamQuality.original] tells Jellyfin
/// to serve the original file untouched; every other tier asks for a
/// transcode via `audioCodec`/`audioBitRate` instead and lets the server
/// decide whether that needs a real transcode or just a remux — the same
/// "existing streaming parameters" approach `ROADMAP.md` calls for,
/// rather than a full `PlaybackInfo`/`DeviceProfile` negotiation.
///
/// The session token travels as an `api_key` query parameter rather than
/// an `Authorization` header. This is deliberate and the one place in
/// Jellyfinity that puts a credential in a URL: a stream URL is handed
/// to a native platform player, which fetches it directly and does not
/// go through `JellyfinHttpClient`'s interceptors, so there is no other
/// way to authenticate the request.
///
/// Registered under a name rather than as *the* [AudioSourceResolver]:
/// from v0.2.0 the resolver the application plays through is
/// `LocalFirstAudioSourceResolver`, which prefers a completed download
/// and falls back to this one.
@Named(remoteAudioSourceResolver)
@LazySingleton(as: AudioSourceResolver)
class JellyfinAudioSourceResolver implements AudioSourceResolver {
  JellyfinAudioSourceResolver(this._context, this._authTokenProvider);

  final JellyfinSessionContext _context;
  final AuthTokenProvider _authTokenProvider;

  @override
  Future<Result<Uri>> resolve(
    MediaId id, {
    StreamQuality quality = StreamQuality.original,
  }) async {
    final baseUrl = _context.baseUrl;
    // Signed out, or the id belongs to a different saved server than the
    // one in use: there is no address to stream from right now — the
    // same guard `JellyfinArtworkResolver` applies to images.
    if (baseUrl == null || id.serverId != _context.serverId) {
      return const Result.err(
        UnauthorizedFailure('Sign in to play from your library.'),
      );
    }

    final token = await _authTokenProvider.currentToken();
    if (token == null || token.isEmpty) {
      return const Result.err(
        UnauthorizedFailure('Sign in to play from your library.'),
      );
    }

    final path = quality.isTranscoded
        ? '/Audio/${id.itemId}/stream.${StreamQuality.transcodeCodec}'
        : '/Audio/${id.itemId}/stream';
    final uri = Uri.tryParse('$baseUrl$path');
    if (uri == null) {
      return const Result.err(
        UnexpectedFailure('Could not build a stream address.'),
      );
    }

    final queryParameters = <String, String>{
      'api_key': token,
      if (quality.isTranscoded) ...{
        'audioCodec': StreamQuality.transcodeCodec,
        'audioBitRate': '${quality.targetBitrateBps}',
      } else
        'static': 'true',
    };

    return Result.ok(uri.replace(queryParameters: queryParameters));
  }
}
