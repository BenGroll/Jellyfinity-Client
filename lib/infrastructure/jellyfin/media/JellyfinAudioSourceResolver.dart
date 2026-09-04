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
/// Builds the direct-play stream address for [id] — `static=true`
/// ([StreamQuality.original], the only quality v0.0.9 implements) tells
/// Jellyfin to serve the original file rather than transcoding it.
///
/// The session token travels as an `api_key` query parameter rather than
/// an `Authorization` header. This is deliberate and the one place in
/// Jellyfinity that puts a credential in a URL: a stream URL is handed
/// to a native platform player, which fetches it directly and does not
/// go through `JellyfinHttpClient`'s interceptors, so there is no other
/// way to authenticate the request.
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

    final uri = Uri.tryParse('$baseUrl/Audio/${id.itemId}/stream');
    if (uri == null) {
      return const Result.err(
        UnexpectedFailure('Could not build a stream address.'),
      );
    }

    return Result.ok(
      uri.replace(
        queryParameters: <String, String>{'static': 'true', 'api_key': token},
      ),
    );
  }
}
