/// What a [MediaItem] is.
///
/// Jellyfin discriminates its one polymorphic item response by a `Type`
/// string; this is Jellyfinity's closed vocabulary for the same idea, so
/// presentation code can branch on media type without knowing Jellyfin's
/// spelling of it.
enum MediaKind {
  artist,
  album,
  track,
  playlist,
  movie,
  series,
  season,
  episode,
}
