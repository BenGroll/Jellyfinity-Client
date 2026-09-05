import '../../core/result/result.dart';
import 'MediaId.dart';

/// Curating the user's playlists: everything [PlaylistRepository] does not
/// cover because it only reads.
///
/// A separate contract, not more methods on `PlaylistRepository`, because
/// the two have different failure/consistency shapes worth keeping apart:
/// a read can be served from the local cache while the server is down, but
/// a write has nowhere to go but the server (`ADR-0016`) and nothing here
/// is ever cached.
///
/// Every mutation goes straight to Jellyfin — Jellyfinity keeps no
/// optimistic local copy of a playlist's edits. Callers that need the
/// result reflected on screen re-read through `PlaylistRepository`
/// afterwards, the same way every other screen in the app already treats
/// the server as the source of truth.
abstract class PlaylistEditor {
  /// Creates a playlist named [name], optionally seeded with [trackIds] in
  /// the given order. Returns the new playlist's id.
  Future<Result<MediaId>> create({
    required String name,
    List<MediaId> trackIds = const [],
  });

  /// Renames [playlistId]. Nothing else about the playlist changes.
  Future<Result<void>> rename(MediaId playlistId, String name);

  /// Deletes [playlistId] itself (not its tracks, which belong to the
  /// library regardless of which playlists reference them).
  Future<Result<void>> delete(MediaId playlistId);

  /// Appends [trackIds] to [playlistId], in order. A track already in the
  /// playlist is added again as a second entry — Jellyfin playlists allow
  /// duplicates, and deciding otherwise is a UI concern, not this one's.
  Future<Result<void>> addTracks(MediaId playlistId, List<MediaId> trackIds);

  /// Removes entries from [playlistId].
  ///
  /// [entryIds] are the playlist's own per-entry ids (`Track.playlistEntryId`
  /// as read from `PlaylistRepository.tracks`), not track ids — a track
  /// present twice in the same playlist has two different entry ids, and
  /// removing "the track" would remove both.
  Future<Result<void>> removeEntries(MediaId playlistId, List<String> entryIds);

  /// Moves the entry [entryId] to [newIndex] within [playlistId].
  Future<Result<void>> moveEntry(
    MediaId playlistId, {
    required String entryId,
    required int newIndex,
  });
}
