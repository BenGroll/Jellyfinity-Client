import 'package:injectable/injectable.dart';

/// Supplies the current Jellyfin session token to the transport layer, or
/// `null` when no user is signed in.
///
/// This is the seam between transport (v0.0.4) and authentication
/// (v0.0.5): the HTTP layer only needs "give me a token if there is one",
/// and does not care where it comes from or how it is stored. v0.0.5
/// replaces [NoAuthTokenProvider] with an implementation backed by secure
/// storage and the active session, without the transport code changing.
abstract class AuthTokenProvider {
  /// The token to attach to outgoing requests, or `null` for an
  /// unauthenticated (but still identified) request.
  Future<String?> currentToken();
}

/// The v0.0.4 implementation: there is never a token yet.
@LazySingleton(as: AuthTokenProvider)
class NoAuthTokenProvider implements AuthTokenProvider {
  const NoAuthTokenProvider();

  @override
  Future<String?> currentToken() async => null;
}
