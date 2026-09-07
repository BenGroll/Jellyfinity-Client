/// Jellyfinity's media vocabulary (v0.0.7, ADR-0011).
///
/// The stable language every media feature speaks: what a piece of media
/// *is* ([MediaItem] and the concrete entities), how it is named
/// ([MediaId]), where it can be played from ([MediaAvailability]), what
/// it looks like ([MediaImage]), how far through it the user got
/// ([PlaybackProgress]), and how collections of it are read in windows
/// ([Page]).
///
/// The repository contracts here are the only way feature code reaches
/// media. Their Jellyfin-backed implementations live in
/// `lib/infrastructure/jellyfin/media/`; nothing above this layer imports
/// them, and nothing above this layer sees a Jellyfin DTO.
///
/// Import this one file rather than reaching into the individual entity
/// files.
library;

export 'Album.dart';
export 'artist.dart';
export 'ArtistStats.dart';
export 'ArtworkResolver.dart';
export 'Episode.dart';
export 'FavoritesRepository.dart';
export 'ListeningContext.dart';
export 'ListeningHistoryEntry.dart';
export 'ListeningHistoryRepository.dart';
export 'media_availability.dart';
export 'MediaId.dart';
export 'MediaImage.dart';
export 'MediaItem.dart';
export 'media_kind.dart';
export 'MediaMetadataRepository.dart';
export 'Movie.dart';
export 'MusicLibraryRepository.dart';
export 'page.dart';
export 'PlaybackProgress.dart';
export 'PlaybackProgressRepository.dart';
export 'Playlist.dart';
export 'PlaylistRepository.dart';
export 'PlaylistTrack.dart';
export 'Season.dart';
export 'Series.dart';
export 'Track.dart';
