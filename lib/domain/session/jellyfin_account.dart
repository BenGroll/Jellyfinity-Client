import 'package:equatable/equatable.dart';

/// A saved profile: one Jellyfin user, signed in on one [JellyfinServer].
///
/// The "saved profile / account" of `CONTEXT.md`'s five session concepts.
/// It pairs a server with a user and is what the account switcher lists.
/// It deliberately holds **no token** — the access token for this account
/// lives only in the credential store, keyed by [id].
///
/// [id] is Jellyfinity's local id (a UUID). [userId] is the Jellyfin
/// user's id on that server. The same person on two servers is two
/// [JellyfinAccount]s.
class JellyfinAccount extends Equatable {
  const JellyfinAccount({
    required this.id,
    required this.serverId,
    required this.userId,
    required this.username,
  });

  /// Jellyfinity's local id for this saved profile (a UUID). Also the key
  /// the credential store stores this account's token under.
  final String id;

  /// The local id of the [JellyfinServer] this account belongs to.
  final String serverId;

  /// The Jellyfin user's id on that server.
  final String userId;

  /// The Jellyfin username, shown in the account switcher.
  final String username;

  JellyfinAccount copyWith({String? username}) {
    return JellyfinAccount(
      id: id,
      serverId: serverId,
      userId: userId,
      username: username ?? this.username,
    );
  }

  @override
  List<Object?> get props => [id, serverId, userId, username];
}
