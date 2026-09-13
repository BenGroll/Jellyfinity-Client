import 'package:equatable/equatable.dart';

/// Which server and which profile a piece of connected-playback state
/// belongs to.
///
/// `Roadmap to v0.6.md`'s first invariant is that connected playback is
/// scoped to one saved server and one authenticated profile, and that
/// Jellyfinity never discovers, commands or transfers across that line
/// *even when Jellyfin grants broader remote-control permissions*. An
/// administrator can see every session on their server; that is the
/// server's answer to "what may you control", not Jellyfinity's answer to
/// "what is this listener's session".
///
/// So the scope is carried explicitly on every device, snapshot, command
/// and envelope rather than being implied by whatever profile happens to
/// be active when a message arrives. A message that arrives after an
/// account switch names the scope it was built for and is dropped,
/// instead of being applied to whoever is signed in now.
///
/// [serverId] is Jellyfinity's own local id for the saved server — the
/// same half [MediaId] carries, for the same reason: it is stable across
/// a server rename and it is what the session layer joins on. [userId] is
/// the Jellyfin user's id on that server. The pair is exactly a saved
/// profile; `JellyfinAccount.id` is deliberately *not* used, because two
/// saved accounts can point at the same user on the same server and their
/// devices are the same devices.
class ConnectedPlaybackScope extends Equatable {
  const ConnectedPlaybackScope({required this.serverId, required this.userId});

  /// Jellyfinity's local id for the server (`JellyfinServer.id`).
  final String serverId;

  /// The Jellyfin user's id on that server.
  final String userId;

  /// A single-string form for wire payloads and map keys. Both halves are
  /// UUIDs, so the separator cannot occur inside either.
  String get key => '$serverId$_separator$userId';

  /// Reverses [key]. Returns `null` for anything malformed, so a message
  /// from a future or corrupted peer degrades to "not for us" instead of
  /// throwing.
  static ConnectedPlaybackScope? tryParse(String? value) {
    if (value == null) return null;
    final parts = value.split(_separator);
    if (parts.length != 2) return null;
    if (parts[0].isEmpty || parts[1].isEmpty) return null;
    return ConnectedPlaybackScope(serverId: parts[0], userId: parts[1]);
  }

  static const String _separator = '/';

  @override
  List<Object?> get props => [serverId, userId];

  @override
  String toString() => 'ConnectedPlaybackScope($key)';
}
