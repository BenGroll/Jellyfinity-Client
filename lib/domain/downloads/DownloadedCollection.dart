import 'package:equatable/equatable.dart';

import '../media/Album.dart';
import '../media/artist.dart';
import '../media/media_availability.dart';
import '../media/MediaId.dart';
import '../media/MediaImage.dart';
import '../media/Playlist.dart';
import 'DownloadOwner.dart';

/// The stored identity of a downloaded album, artist or playlist (v0.2.3).
///
/// v0.2.0–v0.2.2 kept only per-track download records and rebuilt a
/// collection's name and artwork from its tracks. That worked for an
/// album (every track carries its album name) but not for a playlist
/// (whose name is on none of its tracks), and it could say nothing about
/// a collection until at least one of its tracks had been browsed. This
/// type is the missing piece: recorded when the collection is downloaded
/// and refreshed whenever it is opened online, it lets the Downloads
/// screen and the offline library render a collection with the server
/// switched off.
///
/// It is not a [MediaId]-keyed entity of its own — it *is* a
/// [DownloadOwner] ([owner]) plus what it takes to show that owner —
/// so [toAlbum], [toArtist] and [toPlaylist] turn it back into the
/// browse entity the rest of the app speaks.
class DownloadedCollection extends Equatable {
  const DownloadedCollection({
    required this.owner,
    required this.name,
    this.image,
  });

  /// The album, artist or playlist this describes. Its [DownloadOwner.id]
  /// is the collection's [MediaId].
  final DownloadOwner owner;

  final String name;

  /// The artwork pointer captured when the collection was downloaded.
  /// Rendered offline from the artwork disk cache where it was seen
  /// online; `null` (or art never cached) falls back to the placeholder.
  final MediaImage? image;

  MediaId get id => owner.id;
  DownloadOwnerKind get kind => owner.kind;

  /// This collection as an [Album]. [availability] defaults to
  /// [MediaAvailability.localAndRemote]; a caller that has learned the
  /// server no longer lists it passes [MediaAvailability.localOnly].
  Album toAlbum({MediaAvailability availability = MediaAvailability.localAndRemote}) =>
      Album(id: id, name: name, availability: availability, image: image);

  Artist toArtist({
    MediaAvailability availability = MediaAvailability.localAndRemote,
  }) => Artist(id: id, name: name, availability: availability, image: image);

  Playlist toPlaylist({
    MediaAvailability availability = MediaAvailability.localAndRemote,
  }) => Playlist(id: id, name: name, availability: availability, image: image);

  @override
  List<Object?> get props => [owner, name, image];
}
