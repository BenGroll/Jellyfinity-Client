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
/// [serverId] remains Jellyfinity's local id for repositories and cached
/// media. [wireServerId], when available, is Jellyfin's self-reported id
/// and is what crosses between installations: local ids are generated per
/// install and therefore cannot identify the same server to a peer.
class ConnectedPlaybackScope extends Equatable {
  const ConnectedPlaybackScope({
    required this.serverId,
    required this.userId,
    this.wireServerId,
  });

  /// Jellyfinity's local id for the saved server (`JellyfinServer.id`).
  final String serverId;

  /// Jellyfin's server-stable id, for the protocol wire scope only.
  final String? wireServerId;

  /// The Jellyfin user's id on that server.
  final String userId;

  /// A single-string form for wire payloads and map keys.
  String get key => '${wireServerId ?? serverId}$_separator$userId';

  /// Reverses [key]. The result has no local-id mapping because it came
  /// from a peer; envelope decoding replaces it with this device's local
  /// scope after comparing [key].
  static ConnectedPlaybackScope? tryParse(String? value) {
    if (value == null) return null;
    final parts = value.split(_separator);
    if (parts.length != 2) return null;
    if (parts[0].isEmpty || parts[1].isEmpty) return null;
    return ConnectedPlaybackScope(serverId: parts[0], userId: parts[1]);
  }

  static const String _separator = '/';

  @override
  List<Object?> get props => [serverId, userId, wireServerId];

  @override
  String toString() => 'ConnectedPlaybackScope($key)';
}
