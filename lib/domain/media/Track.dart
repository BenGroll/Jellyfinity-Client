import 'artist.dart';
import 'media_availability.dart';
import 'MediaId.dart';
import 'MediaItem.dart';
import 'media_kind.dart';

/// One song.
///
/// A track keeps its album as an id *and* a name: a track list needs the
/// name to render and the id to navigate, and a queue restored offline
/// has to show "which album is this from" without loading the album.
class Track extends MediaItem {
  const Track({
    required super.id,
    required super.name,
    this.artists = const [],
    this.albumId,
    this.albumName,
    this.trackNumber,
    this.discNumber,
    this.duration,
    this.playlistEntryId,
    super.availability = MediaAvailability.remoteOnly,
    super.image,
  });

  final List<ArtistRef> artists;

  final MediaId? albumId;
  final String? albumName;

  /// Position within its disc, when known.
  final int? trackNumber;

  /// Which disc of a multi-disc release, when known.
  final int? discNumber;

  final Duration? duration;

  /// This track's own entry id within the playlist it was just read from
  /// (`PlaylistRepository.tracks`), or `null` outside that context.
  ///
  /// Distinct from [id]: the same track can appear in a playlist more than
  /// once, each occurrence with its own entry id, so removing or
  /// reordering "this row" needs this rather than the track's own id
  /// (`PlaylistEditor.removeEntries`/`moveEntry`).
  final String? playlistEntryId;

  @override
  MediaKind get kind => MediaKind.track;

  @override
  List<Object?> get props => [
    id,
    name,
    artists,
    albumId,
    albumName,
    trackNumber,
    discNumber,
    duration,
    playlistEntryId,
    availability,
    image,
  ];
}
