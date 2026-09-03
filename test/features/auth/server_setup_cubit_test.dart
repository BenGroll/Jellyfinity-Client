import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/features/auth/presentation/server_setup/server_setup_cubit.dart';
import 'package:jellyfinity/infrastructure/jellyfin/http/jellyfin_http_client.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/jellyfin_client_identity.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/jellyfin_server_probe.dart';

import '../../support/fake_dio_adapter.dart';
import '../../support/test_logger.dart';

const _identity = JellyfinClientIdentity(
  clientName: 'Jellyfinity',
  clientVersion: 'test',
  deviceName: 'Test',
  deviceId: 'dev-1',
);

ServerSetupCubit _cubit(FakeDioAdapter adapter) {
  final probe =
      JellyfinServerProbe(_identity, const NoAuthTokenProvider(), TestLogger())
        ..httpClientFactory = (baseUrl) => JellyfinHttpClient(
          baseUrl: baseUrl,
          identity: _identity,
          authTokenProvider: const NoAuthTokenProvider(),
          logger: TestLogger(),
          dio: Dio()..httpClientAdapter = adapter,
          maxRetries: 0,
        );
  return ServerSetupCubit(probe);
}

void main() {
  test('a reachable, supported server yields ServerSetupValid', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({
        'ServerName': 'Home Media',
        'Version': '10.11.6',
        'ProductName': 'Jellyfin Server',
        'Id': 'jf-1',
      }),
    );
    final cubit = _cubit(adapter);

    await cubit.validate('demo.jellyfin.org');

    expect(cubit.state, isA<ServerSetupValid>());
    final server = (cubit.state as ServerSetupValid).server;
    expect(server.baseUrl, 'https://demo.jellyfin.org');
    expect(server.version.toString(), '10.11.6');
  });

  test('an unsupported version yields ServerSetupInvalid', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({
        'Version': '10.9.0',
        'ProductName': 'Jellyfin Server',
      }),
    );
    final cubit = _cubit(adapter);

    await cubit.validate('https://old.example');

    expect(cubit.state, isA<ServerSetupInvalid>());
  });

  test('a bad address is rejected without a request', () async {
    final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));
    final cubit = _cubit(adapter);

    await cubit.validate('   ');

    expect(cubit.state, isA<ServerSetupInvalid>());
    expect(adapter.callCount, 0);
  });

  test('reset returns to the initial state', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({}, statusCode: 500),
    );
    final cubit = _cubit(adapter);
    await cubit.validate('https://example.test');
    expect(cubit.state, isA<ServerSetupInvalid>());

    cubit.reset();

    expect(cubit.state, isA<ServerSetupInitial>());
  });
}
