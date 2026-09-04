import 'package:equatable/equatable.dart';

/// How Jellyfinity names one piece of media.
///
/// A Jellyfin item id is only meaningful **on the server that issued it**:
/// the same album on two servers has two ids, and two servers can in
/// principle hand out the same id for different things. So Jellyfinity
/// never carries a bare item id around — every domain entity is
/// identified by the pair of *which server* and *which item on it*.
///
/// [serverId] is Jellyfinity's own local id for the saved server
/// (`JellyfinServer.id`), not the server's self-reported Jellyfin id: it
/// is the identifier the rest of the application already uses, it is
/// stable across a server renaming or re-installing, and it is the key
/// the session layer joins on.
///
/// This is deliberately *not* portable identity. `OUTLOOK.md` §7 wants
/// share links that resolve media against a different user's server, and
/// §14 wants libraries unified across servers; both need identity built
/// from stable metadata (title, artist, MusicBrainz ids) rather than
/// server ids. Neither is implemented here — but because every entity
/// already carries the server dimension, adding a portable form later is
/// an addition rather than a rewrite of every model, table and cache key.
class MediaId extends Equatable {
  const MediaId({required this.serverId, required this.itemId});

  /// Jellyfinity's local id for the server this item lives on.
  final String serverId;

  /// The item's id on that server, exactly as Jellyfin reported it.
  final String itemId;

  /// A single-string form for cache keys, database columns and route
  /// parameters. Both halves are Jellyfin/Jellyfinity UUIDs, so the
  /// separator cannot occur inside either.
  String get key => '$serverId$_separator$itemId';

  /// Reverses [key]. Returns `null` for anything that is not a
  /// well-formed key, so a stale route or database row degrades to "not
  /// found" instead of throwing.
  static MediaId? tryParse(String key) {
    final separator = key.indexOf(_separator);
    if (separator <= 0 || separator == key.length - 1) return null;
    return MediaId(
      serverId: key.substring(0, separator),
      itemId: key.substring(separator + 1),
    );
  }

  static const String _separator = ':';

  @override
  List<Object?> get props => [serverId, itemId];

  @override
  String toString() => 'MediaId($key)';
}
