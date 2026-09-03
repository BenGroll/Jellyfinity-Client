import 'package:dio/dio.dart';
import 'package:jellyfinity/infrastructure/jellyfin/http/jellyfin_http_client.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/jellyfin_client_identity.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/jellyfin_session_context.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/jellyfin_media_api.dart';

import 'fake_dio_adapter.dart';
import 'test_logger.dart';

const JellyfinClientIdentity testIdentity = JellyfinClientIdentity(
  clientName: 'Jellyfinity',
  clientVersion: 'test',
  deviceName: 'Test',
  deviceId: 'device-1',
);

/// A [JellyfinSessionContext] whose active profile the test controls.
///
/// Its fields are mutable so a test can sign out, or move to a second
/// server, part-way through.
class FakeSessionContext implements JellyfinSessionContext {
  FakeSessionContext({
    this.serverId = 'server-1',
    this.baseUrl = 'https://media.example.com',
    this.userId = 'user-1',
  });

  /// Nobody signed in.
  FakeSessionContext.signedOut()
    : serverId = null,
      baseUrl = null,
      userId = null;

  @override
  String? serverId;

  @override
  String? baseUrl;

  @override
  String? userId;

  void signOut() {
    serverId = null;
    baseUrl = null;
    userId = null;
  }
}

/// A [JellyfinMediaApi] whose requests are answered by [adapter] instead
/// of a Jellyfin server.
JellyfinMediaApi testMediaApi(
  FakeDioAdapter adapter, {
  JellyfinSessionContext? context,
}) {
  return JellyfinMediaApi(
      context ?? FakeSessionContext(),
      testIdentity,
      const NoAuthTokenProvider(),
      TestLogger(),
    )
    ..httpClientFactory = (baseUrl) => JellyfinHttpClient(
      baseUrl: baseUrl,
      identity: testIdentity,
      authTokenProvider: const NoAuthTokenProvider(),
      logger: TestLogger(),
      dio: Dio()..httpClientAdapter = adapter,
      maxRetries: 0,
    );
}

/// A Jellyfin collection response.
Map<String, dynamic> itemsResponse(
  List<Map<String, dynamic>> items, {
  int? totalRecordCount,
  int startIndex = 0,
}) {
  return {
    'Items': items,
    'TotalRecordCount': totalRecordCount ?? items.length,
    'StartIndex': startIndex,
  };
}
