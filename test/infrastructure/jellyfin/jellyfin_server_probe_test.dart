import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/jellyfin_client_identity.dart';
import 'package:jellyfinity/infrastructure/jellyfin/http/jellyfin_http_client.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/jellyfin_server_probe.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/minimum_server_version_policy.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/server_version.dart';

import '../../support/fake_dio_adapter.dart';
import '../../support/test_logger.dart';

const _identity = JellyfinClientIdentity(
  clientName: 'Jellyfinity',
  clientVersion: '0.0.4',
  deviceName: 'Test',
  deviceId: 'dev-1',
);

/// A probe whose HTTP client is wired to [adapter] instead of the network.
JellyfinServerProbe _probe(FakeDioAdapter adapter) {
  return JellyfinServerProbe(
      _identity,
      const NoAuthTokenProvider(),
      TestLogger(),
    )
    ..httpClientFactory = (baseUrl) {
      final dio = Dio()..httpClientAdapter = adapter;
      return JellyfinHttpClient(
        baseUrl: baseUrl,
        identity: _identity,
        authTokenProvider: const NoAuthTokenProvider(),
        logger: TestLogger(),
        dio: dio,
        maxRetries: 0,
      );
    };
}

Map<String, Object?> _publicInfo({
  String version = '10.11.6',
  String productName = 'Jellyfin Server',
}) => {
  'ServerName': 'Home Media',
  'Version': version,
  'ProductName': productName,
  'Id': 'server-abc',
};

void main() {
  test('accepts a reachable, supported Jellyfin server', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(_publicInfo()),
    );
    final result = await _probe(adapter).validate('demo.jellyfin.org');

    final info = result.valueOrNull;
    expect(info, isNotNull);
    expect(info!.baseUrl, 'https://demo.jellyfin.org');
    expect(info.serverName, 'Home Media');
    expect(info.serverId, 'server-abc');
    expect(info.version.toString(), '10.11.6');
  });

  test('calls the public system-info endpoint', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(_publicInfo()),
    );
    await _probe(adapter).validate('https://example.test');

    expect(adapter.requests.single.path, '/System/Info/Public');
  });

  test('rejects a server older than the minimum version', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(_publicInfo(version: '10.11.5')),
    );
    final result = await _probe(adapter).validate('https://old.example');

    expect(result.failureOrNull, isA<UnsupportedServerFailure>());
    expect(result.failureOrNull!.message, contains('10.11.5'));
  });

  test('rejects a non-Jellyfin server that still answers with JSON', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(_publicInfo(productName: 'Emby Server')),
    );
    final result = await _probe(adapter).validate('https://emby.example');

    expect(result.failureOrNull, isA<UnsupportedServerFailure>());
  });

  test('rejects a response with no readable version', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({'ProductName': 'Jellyfin Server'}),
    );
    final result = await _probe(adapter).validate('https://example.test');

    expect(result.failureOrNull, isA<UnsupportedServerFailure>());
  });

  test('surfaces an unauthorized response as UnauthorizedFailure', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({}, statusCode: 401),
    );
    final result = await _probe(adapter).validate('https://example.test');

    expect(result.failureOrNull, isA<UnauthorizedFailure>());
  });

  test('surfaces a connection failure as RecoverableFailure', () async {
    final adapter = FakeDioAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final result = await _probe(
      adapter,
    ).validate('https://unreachable.example');

    expect(result.failureOrNull, isA<RecoverableFailure>());
  });

  test('surfaces malformed JSON as an unreadable-response failure', () async {
    final adapter = FakeDioAdapter(
      (_) async => textResponseBody('<html>nope</html>'),
    );
    final result = await _probe(adapter).validate('https://example.test');

    expect(result.failureOrNull, isA<UnexpectedFailure>());
  });

  test('rejects a bad address before any request is made', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(_publicInfo()),
    );
    final result = await _probe(adapter).validate('   ');

    expect(result.failureOrNull, isA<RecoverableFailure>());
    expect(adapter.callCount, 0);
  });

  test('honours a lowered version policy', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(_publicInfo(version: '10.9.0')),
    );
    final probe = _probe(adapter)
      ..versionPolicy = const MinimumServerVersionPolicy(
        ServerVersion(10, 9, 0),
      );
    final result = await probe.validate('https://example.test');

    expect(result.isOk, isTrue);
  });
}
