import 'package:equatable/equatable.dart';

/// What a successful Jellyfin credential authentication yields: the
/// server's identification of the user, plus the access token minted for
/// this device.
///
/// The output of [JellyfinAuthenticator.authenticate]. It is a transport
/// result, not yet a saved thing — the session layer turns it into a
/// [JellyfinAccount] (assigning a local id) and hands the token to the
/// credential store.
class AuthenticatedUser extends Equatable {
  const AuthenticatedUser({
    required this.userId,
    required this.username,
    required this.accessToken,
  });

  /// The Jellyfin user's id on the server that authenticated them.
  final String userId;

  /// The Jellyfin username the server echoed back (canonical casing).
  final String username;

  /// The access token the server issued. Sensitive.
  final String accessToken;

  @override
  List<Object?> get props => [userId, username, accessToken];

  @override
  String toString() => 'AuthenticatedUser(username: $username)';
}
