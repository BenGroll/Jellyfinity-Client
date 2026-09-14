import '../../core/result/result.dart';
import '../playback/repeat_mode.dart';
import 'ConnectedPlaybackScope.dart';
import 'RemoteQueueEntry.dart';
import 'SyncPlayGroupUpdate.dart';

/// The server-side half of group playback (v0.6.0, ADR-0045): Jellyfin's
/// own SyncPlay REST surface plus the `GroupUpdate` stream that arrives
/// over the same shared WebSocket every other connected-playback message
/// already rides (ADR-0038's "Jellyfin is the only relay," extended to a
/// second message type on the one socket rather than a second one).
///
/// Deliberately not [ConnectedPlaybackTransport]: a SyncPlay group is
/// Jellyfin's concept, addressed by its own REST endpoints, not a
/// Jellyfinity-to-Jellyfinity envelope `DeviceCapabilities` negotiates.
abstract class SyncPlayTransport {
  /// `GroupUpdate` messages for the group this device is currently in, or
  /// has just asked to join — scoped the same way every other connected-
  /// playback stream is, so an update from another profile's group (a
  /// stale subscription surviving an account switch) is never mistaken
  /// for this one's.
  Stream<SyncPlayGroupUpdate> groupUpdates(ConnectedPlaybackScope scope);

  /// Creates a new group and joins it in one step — Jellyfin's `/SyncPlay
  /// /New` reports success as an ordinary group join, so the real answer
  /// arrives on [groupUpdates] as a [SyncPlayGroupJoined], not in this
  /// call's own result.
  Future<Result<void>> createGroup(ConnectedPlaybackScope scope);

  /// Joins an existing group by id — used both for the device picker's
  /// "play on all devices" when a group already exists, and for
  /// rejoining one this device dropped out of.
  Future<Result<void>> joinGroup(ConnectedPlaybackScope scope, String groupId);

  /// Leaves whatever group this device is currently in. A no-op,
  /// answered [Result.ok], if it is not in one.
  Future<Result<void>> leaveGroup(ConnectedPlaybackScope scope);

  /// Sets the group's one shared queue — the SyncPlay counterpart to
  /// `SetQueueCommand`, sent to the *group* rather than one target.
  Future<Result<void>> setQueue(
    ConnectedPlaybackScope scope, {
    required List<RemoteQueueEntry> entries,
    required int startIndex,
    required bool shuffleEnabled,
    required RepeatMode repeatMode,
    Duration startPosition,
  });

  /// Tells the group to play, from whatever position it currently shares.
  Future<Result<void>> play(ConnectedPlaybackScope scope);

  Future<Result<void>> pause(ConnectedPlaybackScope scope);

  Future<Result<void>> seek(ConnectedPlaybackScope scope, Duration position);
}
