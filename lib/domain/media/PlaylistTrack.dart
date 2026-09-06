import 'Track.dart';

/// A track *as it sits in one playlist*, carrying the playlist's own
/// handle for that row.
///
/// A playlist is a list of entries, not a set of tracks. The same song can
/// appear in it three times, and Jellyfin gives each of those appearances
/// its own `PlaylistItemId` — which is what its remove and reorder
/// endpoints take. Removing "that song" from a playlist is therefore not a
/// well-formed request; removing *that row* is.
///
/// This is a subtype rather than a nullable field on [Track] because an
/// entry id is only meaningful for a track that was read from a playlist.
/// A track from the library, the queue, or a download record has no entry
/// id and should not carry a slot for one.
///
/// The [PlaylistRepository] contract still speaks in [Track]: the
/// Jellyfin-backed read produces these, while a read served from the
/// offline cache or a download snapshot produces plain [Track]s, because
/// neither stores entry ids. A caller that wants to edit a playlist asks
/// whether the row it has is a [PlaylistTrack] — which is also the honest
/// answer to "can this row be removed right now", since editing needs the
/// server anyway.
class PlaylistTrack extends Track {
  const PlaylistTrack({
    required this.entryId,
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

  /// Jellyfin's `PlaylistItemId` for this row — the playlist's handle for
  /// this appearance of the track, not the track's own id.
  final String entryId;

  @override
  List<Object?> get props => [...super.props, entryId];
}
