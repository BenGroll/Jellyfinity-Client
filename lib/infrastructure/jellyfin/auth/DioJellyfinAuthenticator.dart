import 'package:injectable/injectable.dart';

import '../../../core/logging/Logger.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/session/AuthenticatedUser.dart';
import '../../../domain/session/JellyfinAuthenticator.dart';
import '../../../domain/session/JellyfinServer.dart';
import '../identity/auth_token_provider.dart';
import '../identity/JellyfinClientIdentity.dart';
import '../http/JellyfinHttpClient.dart';
import 'authentication_result_dto.dart';

/// Builds a [JellyfinHttpClient] for a base URL. Injected so tests can
/// supply a client wired to a fake `dio` adapter (same pattern as
/// `JellyfinServerProbe`).
typedef AuthHttpClientFactory = JellyfinHttpClient Function(String baseUrl);

/// [JellyfinAuthenticator] that calls Jellyfin's `AuthenticateByName`
/// endpoint over the shared transport layer.
///
/// The request carries only the client identity header (no token yet);
/// the password is in the POST body and never appears in a log line —
/// `CorrelationInterceptor` logs method and path only.
@LazySingleton(as: JellyfinAuthenticator)
class DioJellyfinAuthenticator implements JellyfinAuthenticator {
  DioJellyfinAuthenticator(this._identity, this._logger);

  final JellyfinClientIdentity _identity;
  final Logger _logger;

  /// Jellyfin's credential authentication endpoint.
  static const String authenticateByNamePath = '/Users/AuthenticateByName';

  /// Overrides how the HTTP client is built. `null` in production.
  AuthHttpClientFactory? httpClientFactory;

  @override
  Future<Result<AuthenticatedUser>> authenticate({
    required JellyfinServer server,
    required String username,
    required String password,
  }) async {
    final client = (httpClientFactory ?? _defaultClient)(server.baseUrl);
    try {
      final result = await client.postJson<AuthenticationResultDto>(
        authenticateByNamePath,
        body: {'Username': username, 'Pw': password},
        parse: AuthenticationResultDto.fromJson,
      );

      return result.when(
        ok: (dto) {
          final token = dto.accessToken;
          final userId = dto.user?.id;
          if (token == null || token.isEmpty || userId == null) {
            _logger.warning(
              'AuthenticateByName succeeded but the response was missing a '
              'token or user id.',
            );
            return const Result.err(
              UnexpectedFailure(
                'The server accepted the sign-in but sent back an '
                'unexpected response.',
              ),
            );
          }
          return Result.ok(
            AuthenticatedUser(
              userId: userId,
              username: dto.user?.name ?? username,
              accessToken: token,
            ),
          );
        },
        err: (failure) {
          // 401 from this endpoint means the credentials were wrong, not
          // that a session expired — give it a login-appropriate message.
          if (failure is UnauthorizedFailure) {
            return const Result.err(
              UnauthorizedFailure('Incorrect username or password.'),
            );
          }
          return Result.err(failure);
        },
      );
    } finally {
      client.close();
    }
  }

  JellyfinHttpClient _defaultClient(String baseUrl) => JellyfinHttpClient(
    baseUrl: baseUrl,
    identity: _identity,
    // Authentication requests are token-less by definition.
    authTokenProvider: const NoAuthTokenProvider(),
    logger: _logger,
  );
}
