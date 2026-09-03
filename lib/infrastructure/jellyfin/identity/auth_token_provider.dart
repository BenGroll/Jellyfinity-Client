/// Supplies the current Jellyfin session token to the transport layer, or
/// `null` when no user is signed in.
///
/// This is the seam between transport (v0.0.4) and authentication
/// (v0.0.5): the HTTP layer only needs "give me a token if there is one",
/// and does not care where it comes from or how it is stored. v0.0.5's
/// `SessionAuthTokenProvider` (in `lib/app/session/`) is the DI-registered
/// implementation, backed by the active session; the transport code did
/// not change.
abstract class AuthTokenProvider {
  /// The token to attach to outgoing requests, or `null` for an
  /// unauthenticated (but still identified) request.
  Future<String?> currentToken();
}

/// A provider that never has a token. Used for requests that are
/// token-less by definition — server probing and credential
/// authentication — and as a test double.
class NoAuthTokenProvider implements AuthTokenProvider {
  const NoAuthTokenProvider();

  @override
  Future<String?> currentToken() async => null;
}
