import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/JellyfinClientIdentity.dart';
import 'package:jellyfinity/infrastructure/jellyfin/http/JellyfinHttpClient.dart';

import '../../support/FakeDioAdapter.dart';
import '../../support/TestLogger.dart';

const _identity = JellyfinClientIdentity(
  clientName: 'Jellyfinity',
  clientVersion: '0.0.4',
  deviceName: 'Test',
  deviceId: 'dev-1',
);

class _StubTokenProvider implements AuthTokenProvider {
  _StubTokenProvider(this._token);
  final String? _token;
  @override
  Future<String?> currentToken() async => _token;
}

JellyfinHttpClient _client(
  FakeDioAdapter adapter, {
  AuthTokenProvider? tokens,
  int maxRetries = 2,
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return JellyfinHttpClient(
    baseUrl: 'https://example.test',
    identity: _identity,
    authTokenProvider: tokens ?? const NoAuthTokenProvider(),
    logger: TestLogger(),
    dio: dio,
    maxRetries: maxRetries,
  );
}

void main() {
  group('getJson', () {
    test('decodes a JSON object body via the parser', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody({'Version': '10.11.6'}),
      );
      final result = await _client(adapter).getJson<String?>(
        '/System/Info/Public',
        parse: (json) => json['Version'] as String?,
      );

      expect(result.valueOrNull, '10.11.6');
    });

    test(
      'normalizes a transport failure to a Failure (no exception escapes)',
      () async {
        final adapter = FakeDioAdapter(
          (options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        );
        final result = await _client(
          adapter,
          maxRetries: 0,
        ).getJson<String?>('/x', parse: (json) => null);

        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isA<RecoverableFailure>());
      },
    );

    test('maps a 401 response to UnauthorizedFailure', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody({'error': 'nope'}, statusCode: 401),
      );
      final result = await _client(
        adapter,
      ).getJson<String?>('/x', parse: (_) => null);

      expect(result.failureOrNull, isA<UnauthorizedFailure>());
    });

    test('rejects a non-object body as unreadable', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody('just a string'),
      );
      final result = await _client(
        adapter,
      ).getJson<String?>('/x', parse: (_) => 'x');

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });

    test(
      'turns a throwing parser into an unreadable-response failure',
      () async {
        final adapter = FakeDioAdapter(
          (_) async => jsonResponseBody({'Version': 42}),
        );
        final result = await _client(
          adapter,
        ).getJson<String>('/x', parse: (json) => json['Version'] as String);

        expect(result.failureOrNull, isA<UnexpectedFailure>());
      },
    );
  });

  group('authorization header', () {
    test(
      'is sent on every request, without a token when unauthenticated',
      () async {
        final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));
        await _client(adapter).getJson<void>('/x', parse: (_) {});

        final header =
            adapter.requests.single.headers[JellyfinClientIdentity
                    .authorizationHeader]
                as String;
        expect(header, contains('Client="Jellyfinity"'));
        expect(header, contains('DeviceId="dev-1"'));
        expect(header, isNot(contains('Token=')));
      },
    );

    test('carries the token once the provider has one', () async {
      final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));
      await _client(
        adapter,
        tokens: _StubTokenProvider('t-123'),
      ).getJson<void>('/x', parse: (_) {});

      final header =
          adapter.requests.single.headers[JellyfinClientIdentity
                  .authorizationHeader]
              as String;
      expect(header, contains('Token="t-123"'));
    });
  });

  group('bounded retry', () {
    test(
      'retries a transient GET failure up to the limit, then gives up',
      () async {
        final adapter = FakeDioAdapter(
          (options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        );
        final result = await _client(
          adapter,
          maxRetries: 2,
        ).getJson<void>('/x', parse: (_) {});

        expect(result.isErr, isTrue);
        expect(adapter.callCount, 3); // 1 initial + 2 retries
      },
    );

    test('succeeds if a retry succeeds', () async {
      var attempts = 0;
      final adapter = FakeDioAdapter((options) async {
        attempts++;
        if (attempts < 2) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonResponseBody({'ok': true});
      });
      final result = await _client(
        adapter,
        maxRetries: 2,
      ).getJson<bool>('/x', parse: (json) => json['ok'] as bool);

      expect(result.valueOrNull, isTrue);
      expect(adapter.callCount, 2);
    });

    test('does not retry a non-transient (bad-response) failure', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody({'e': 1}, statusCode: 500),
      );
      await _client(adapter, maxRetries: 2).getJson<void>('/x', parse: (_) {});

      expect(adapter.callCount, 1);
    });
  });
}
