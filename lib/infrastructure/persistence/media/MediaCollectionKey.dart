/// Names the collection a cached window belongs to.
///
/// A cached page is only meaningful together with the question that
/// produced it: position 3 of "this artist's albums" is not position 3 of
/// "every album". These keys are that question, written as one string, so
/// the cache tables need a single column instead of one nullable filter
/// column per kind of query.
///
/// The keys embed Jellyfin item ids but never a server id — the server is
/// the other half of the primary key on every cache table, so a key is
/// only ever compared within one server's rows.
///
/// Search results deliberately have no key. ADR-0010 files them under
/// "temporary cache": they are cheap to re-ask for, they go stale the
/// moment the library changes, and persisting them would fill the cache
/// with windows nobody browses twice.
abstract final class MediaCollectionKey {
  /// Every album artist in the library.
  static const artists = 'artists';

  /// Every album in the library.
  static const albums = 'albums';

  /// Every song in the library.
  static const tracks = 'tracks';

  /// The user's playlists.
  static const playlists = 'playlists';

  /// One artist's albums, in the order the artist page shows them.
  static String albumsOfArtist(String artistItemId) =>
      'albums:artist=$artistItemId';

  /// One album's tracks, in disc and track order.
  static String tracksOfAlbum(String albumItemId) =>
      'tracks:album=$albumItemId';

  /// Everything one artist appears on.
  static String tracksOfArtist(String artistItemId) =>
      'tracks:artist=$artistItemId';

  /// One playlist's entries, in the user's own arrangement.
  static String tracksOfPlaylist(String playlistItemId) =>
      'playlist:$playlistItemId';
}
