import '../../core/result/result.dart';
import 'authenticated_user.dart';
import 'jellyfin_server.dart';

/// Exchanges a username and password for a Jellyfin access token.
///
/// The one domain contract that actually talks to a server during the
/// login flow (server *validation* is the transport layer's
/// `JellyfinServerProbe`, called first). The infrastructure implementation
/// posts to Jellyfin's `AuthenticateByName` endpoint and maps the result.
///
/// Failures come back as the ADR-0004 `Failure` model — never a raw
/// exception, and never with the password in the message:
/// - wrong username/password → `UnauthorizedFailure`
/// - server unreachable / timed out → `RecoverableFailure`
/// - TLS problem → `UnavailableFailure`
/// - anything else → `UnexpectedFailure`
abstract class JellyfinAuthenticator {
  Future<Result<AuthenticatedUser>> authenticate({
    required JellyfinServer server,
    required String username,
    required String password,
  });
}
