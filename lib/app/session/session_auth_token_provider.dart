import 'package:injectable/injectable.dart';

import '../../infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'auth_session_manager.dart';

/// The real [AuthTokenProvider] (v0.0.5): hands the transport layer the
/// active profile's access token, straight from [AuthSessionManager].
///
/// This is the seam ADR-0008 left for authentication. It lives in
/// `lib/app` because it depends on the session manager (an app-layer
/// composition concern); the transport layer only ever sees the
/// `AuthTokenProvider` interface, exactly as before.
///
/// The read is synchronous under the hood (an in-memory field), so it
/// adds nothing measurable to each request.
@LazySingleton(as: AuthTokenProvider)
class SessionAuthTokenProvider implements AuthTokenProvider {
  SessionAuthTokenProvider(this._sessions);

  final AuthSessionManager _sessions;

  @override
  Future<String?> currentToken() async => _sessions.currentToken;
}
