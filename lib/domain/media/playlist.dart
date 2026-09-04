import 'media_availability.dart';
import 'media_item.dart';
import 'media_kind.dart';

/// A user's playlist.
///
/// Jellyfin playlists can hold mixed media; Jellyfinity's playlist
/// browsing is music-scoped for now (v0.0.8), and this entity describes
/// the playlist itself rather than its contents — those are paged
/// separately through `PlaylistRepository.tracks`.
class Playlist extends MediaItem {
  const Playlist({
    required super.id,
    required super.name,
    this.itemCount,
    this.duration,
    super.availability = MediaAvailability.remoteOnly,
    super.image,
  });

  final int? itemCount;
  final Duration? duration;

  @override
  MediaKind get kind => MediaKind.playlist;

  @override
  List<Object?> get props => [
    id,
    name,
    itemCount,
    duration,
    availability,
    image,
  ];
}
