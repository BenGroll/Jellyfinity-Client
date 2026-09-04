import 'package:equatable/equatable.dart';

import 'JellyfinAccount.dart';
import 'JellyfinServer.dart';

/// The fully-resolved, ready-to-use session for the active profile:
/// an [account], the [server] it lives on, and the [accessToken] to
/// authenticate its requests.
///
/// This is a *runtime* value, assembled at login or on session restore by
/// joining a [JellyfinAccount], its [JellyfinServer], and the token read
/// from the credential store. It is never persisted as a unit — that
/// would mean writing the token next to non-secret data. Later media
/// features read [server] (for the base URL) and go through the token
/// provider seam for [accessToken]; they should not need anything else to
/// talk to Jellyfin.
///
/// The token is held here in memory only. It is never logged and never
/// put in a [toString] (see the override below).
class AuthSession extends Equatable {
  const AuthSession({
    required this.account,
    required this.server,
    required this.accessToken,
  });

  final JellyfinAccount account;
  final JellyfinServer server;

  /// The Jellyfin access token for [account]. Sensitive — treat like a
  /// password: never log it, never render it, never persist it outside
  /// the credential store.
  final String accessToken;

  @override
  List<Object?> get props => [account, server, accessToken];

  /// Deliberately omits the token so it cannot leak through a log line or
  /// an error message that happens to interpolate a session.
  @override
  String toString() =>
      'AuthSession(account: ${account.username}, server: ${server.baseUrl})';
}
