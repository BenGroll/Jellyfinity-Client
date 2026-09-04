import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/playback/stream_quality.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinAudioSourceResolver.dart';

import '../../../support/FakeSessionContext.dart';

class _FixedTokenProvider implements AuthTokenProvider {
  const _FixedTokenProvider(this._token);

  final String? _token;

  @override
  Future<String?> currentToken() async => _token;
}

const _trackId = MediaId(serverId: 'server-1', itemId: 'track-1');

void main() {
  test(
    'builds a direct-play stream address with the token as api_key',
    () async {
      final resolver = JellyfinAudioSourceResolver(
        FakeSessionContext(),
        const _FixedTokenProvider('secret-token'),
      );

      final result = await resolver.resolve(_trackId);

      final url = (result as Ok<Uri>).value;
      expect(url.origin, 'https://media.example.com');
      expect(url.path, '/Audio/track-1/stream');
      expect(url.queryParameters['static'], 'true');
      expect(url.queryParameters['api_key'], 'secret-token');
    },
  );

  test('keeps a base path when the server is behind a reverse proxy', () async {
    final resolver = JellyfinAudioSourceResolver(
      FakeSessionContext(baseUrl: 'https://home.example.com/jellyfin'),
      const _FixedTokenProvider('secret-token'),
    );

    final result = await resolver.resolve(_trackId);

    expect((result as Ok<Uri>).value.path, '/jellyfin/Audio/track-1/stream');
  });

  test(
    "refuses to stream from a different server than the active one",
    () async {
      final resolver = JellyfinAudioSourceResolver(
        FakeSessionContext(),
        const _FixedTokenProvider('secret-token'),
      );

      final result = await resolver.resolve(
        const MediaId(serverId: 'server-2', itemId: 'track-1'),
      );

      expect(result.failureOrNull, isA<UnauthorizedFailure>());
    },
  );

  test('refuses to stream while signed out', () async {
    final resolver = JellyfinAudioSourceResolver(
      FakeSessionContext.signedOut(),
      const _FixedTokenProvider('secret-token'),
    );

    final result = await resolver.resolve(_trackId);

    expect(result.failureOrNull, isA<UnauthorizedFailure>());
  });

  test('refuses to stream without a session token', () async {
    final resolver = JellyfinAudioSourceResolver(
      FakeSessionContext(),
      const _FixedTokenProvider(null),
    );

    final result = await resolver.resolve(_trackId);

    expect(result.failureOrNull, isA<UnauthorizedFailure>());
  });

  group('transcoded tiers (ADR-0015)', () {
    for (final (quality, bitrate) in [
      (StreamQuality.high, StreamQuality.highBitrateBps),
      (StreamQuality.medium, StreamQuality.mediumBitrateBps),
      (StreamQuality.dataSaver, StreamQuality.dataSaverBitrateBps),
    ]) {
      test(
        '${quality.name} requests an aac transcode at $bitrate bps',
        () async {
          final resolver = JellyfinAudioSourceResolver(
            FakeSessionContext(),
            const _FixedTokenProvider('secret-token'),
          );

          final result = await resolver.resolve(_trackId, quality: quality);

          final url = (result as Ok<Uri>).value;
          expect(url.path, '/Audio/track-1/stream.aac');
          expect(url.queryParameters['audioCodec'], 'aac');
          expect(url.queryParameters['audioBitRate'], '$bitrate');
          expect(url.queryParameters['api_key'], 'secret-token');
          expect(
            url.queryParameters.containsKey('static'),
            isFalse,
            reason: 'static=true would force direct-play, defeating the tier',
          );
        },
      );
    }

    test(
      'a transcoded tier still refuses to stream while signed out',
      () async {
        final resolver = JellyfinAudioSourceResolver(
          FakeSessionContext.signedOut(),
          const _FixedTokenProvider('secret-token'),
        );

        final result = await resolver.resolve(
          _trackId,
          quality: StreamQuality.high,
        );

        expect(result.failureOrNull, isA<UnauthorizedFailure>());
      },
    );
  });
}
