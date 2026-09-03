import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/session/jellyfin_server.dart';
import 'package:jellyfinity/infrastructure/jellyfin/auth/dio_jellyfin_authenticator.dart';
import 'package:jellyfinity/infrastructure/jellyfin/http/jellyfin_http_client.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/jellyfin_client_identity.dart';

import '../../../support/fake_dio_adapter.dart';
import '../../../support/test_logger.dart';

const _identity = JellyfinClientIdentity(
  clientName: 'Jellyfinity',
  clientVersion: 'test',
  deviceName: 'Test',
  deviceId: 'dev-1',
);

const _server = JellyfinServer(
  id: 's1',
  baseUrl: 'https://media.example.com',
  name: 'Home',
  reportedVersion: '10.11.6',
);

DioJellyfinAuthenticator _authenticator(FakeDioAdapter adapter) {
  return DioJellyfinAuthenticator(_identity, TestLogger())
    ..httpClientFactory = (baseUrl) => JellyfinHttpClient(
      baseUrl: baseUrl,
      identity: _identity,
      authTokenProvider: const NoAuthTokenProvider(),
      logger: TestLogger(),
      dio: Dio()..httpClientAdapter = adapter,
      maxRetries: 0,
    );
}

void main() {
  test('maps a successful response to an AuthenticatedUser', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({
        'User': {'Id': 'user-1', 'Name': 'Alice'},
        'AccessToken': 'secret-token',
        'ServerId': 'jf-1',
      }),
    );

    final result = await _authenticator(
      adapter,
    ).authenticate(server: _server, username: 'alice', password: 'hunter2');

    final user = result.valueOrNull;
    expect(user, isNotNull);
    expect(user!.userId, 'user-1');
    expect(user.username, 'Alice');
    expect(user.accessToken, 'secret-token');
  });

  test(
    'posts to AuthenticateByName with the credentials in the body',
    () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody({
          'User': {'Id': 'user-1', 'Name': 'alice'},
          'AccessToken': 't',
        }),
      );

      await _authenticator(
        adapter,
      ).authenticate(server: _server, username: 'alice', password: 'hunter2');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/Users/AuthenticateByName');
      expect(request.data, {'Username': 'alice', 'Pw': 'hunter2'});
    },
  );

  test('turns a 401 into a login-appropriate UnauthorizedFailure', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({}, statusCode: 401),
    );

    final result = await _authenticator(
      adapter,
    ).authenticate(server: _server, username: 'alice', password: 'wrong');

    final failure = result.failureOrNull;
    expect(failure, isA<UnauthorizedFailure>());
    expect(failure!.message, 'Incorrect username or password.');
  });

  test('a connection failure is recoverable', () async {
    final adapter = FakeDioAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );

    final result = await _authenticator(
      adapter,
    ).authenticate(server: _server, username: 'alice', password: 'hunter2');

    expect(result.failureOrNull, isA<RecoverableFailure>());
  });

  test('a 200 without a token is an unexpected failure', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({
        'User': {'Id': 'user-1', 'Name': 'alice'},
      }),
    );

    final result = await _authenticator(
      adapter,
    ).authenticate(server: _server, username: 'alice', password: 'hunter2');

    expect(result.failureOrNull, isA<UnexpectedFailure>());
  });
}
