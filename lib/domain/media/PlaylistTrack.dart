import 'Track.dart';

/// A track *as it sits in one playlist* — carrying that row's true
/// position in the playlist and, when the server named one, the
/// playlist's own handle for it.
///
/// A playlist is a list of entries, not a set of tracks. The same song can
/// appear in it three times, and Jellyfin gives each of those appearances
/// its own `PlaylistItemId` — which is what its remove and move endpoints
/// take. Removing "that song" from a playlist is therefore not a
/// well-formed request; removing *that row* is.
///
/// This is a subtype rather than two nullable fields on [Track] because
/// neither a position nor an entry id is meaningful for a track that was
/// not read from a playlist. A track from the library, the queue, or a
/// download record has neither and should not carry slots for them.
///
/// ## Position and entry id answer different questions (v0.4.2)
///
/// ADR-0024 fused them: it made `row is PlaylistTrack` mean both "this row
/// knows its entry id" and "this row can be edited", because at the time
/// the only source that produced one was the live Jellyfin read.
/// Finishing reorder needed positions offline too — an offline list still
/// has to number itself the way the playlist does — so the two are now
/// separate:
///
/// - [position] is where this row sits in the playlist, counted the way
///   Jellyfin counts it: entries Jellyfinity cannot read still occupy
///   their slots. Every source that knows the order fills it in, the
///   saved copy and a download snapshot included.
/// - [entryId] is the handle a write needs, and only a read that reached
///   the server has one. `null` means this row cannot be removed or moved
///   right now — offline, from a download snapshot, or (rarely) because
///   the server sent the row without a `PlaylistItemId`. The row stays
///   listed and playable either way; [isEditable] is the question the UI
///   asks.
///
/// The [PlaylistRepository] contract still speaks in [Track], because a
/// caller that only wants to play the list does not care which of these
/// it got.
class PlaylistTrack extends Track {
  const PlaylistTrack({
    required this.position,
    this.entryId,
    required super.id,
    required super.name,
    super.artists,
    super.albumId,
    super.albumName,
    super.trackNumber,
    super.discNumber,
    super.duration,
    super.normalizationGain,
    super.isFavorite,
    super.availability,
    super.image,
  });

  /// This row's zero-based index in the playlist as a whole — including
  /// the entries Jellyfinity could not map, and counting past the start of
  /// whichever window this row arrived in.
  ///
  /// This is the number Jellyfin's move endpoint speaks in, and (plus one)
  /// the number the list shows.
  final int position;

  /// Jellyfin's `PlaylistItemId` for this row — the playlist's handle for
  /// this appearance of the track, not the track's own id. `null` when the
  /// read that produced this row never had one; see [isEditable].
  final String? entryId;

  /// Whether this row can be removed from or moved within its playlist
  /// right now. Editing a playlist is an online-only capability
  /// (ADR-0024), and an entry id is exactly what a read that reached the
  /// server brings back, so this one answer covers both.
  bool get isEditable => entryId != null;

  @override
  List<Object?> get props => [...super.props, position, entryId];
}
