import '../../../domain/connected_playback/DeviceObservation.dart';

/// One entry of Jellyfin's `/Sessions` response, reduced to the fields
/// connected playback actually reads.
///
/// A transport model, kept distinct from `ConnectedDevice` as
/// `CONTEXT.md` requires: this is Jellyfin's idea of a session, including
/// the parts Jellyfinity has no use for, and it stops at the edge of the
/// infrastructure layer. [toObservation] is the only way across.
///
/// Parsing is deliberately forgiving in the same way
/// `ConnectedPlaybackEnvelope.decode` is. A session record is one row in
/// a list that also contains web clients, other people's phones and
/// whatever else is signed in; a row Jellyfinity cannot read is a row to
/// skip, not a reason to fail the whole device list.
class JellyfinSessionDto {
  const JellyfinSessionDto({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.client,
    required this.userId,
    required this.supportsRemoteControl,
    required this.isPlaying,
    this.applicationVersion,
  });

  /// The ephemeral session id — Jellyfin's `Id`, and the address a
  /// command is sent to.
  final String id;

  /// The stable install id — Jellyfin's `DeviceId`, which for a
  /// Jellyfinity peer is the id `DeviceIdentityStore` persists.
  final String deviceId;

  final String deviceName;

  /// The product name the session reports — `Jellyfinity` for a peer,
  /// `Jellyfin Web` or anything else for the rest of the list.
  final String client;

  /// The Jellyfin user this session is signed in as. The field account
  /// isolation is enforced on.
  final String userId;

  final bool supportsRemoteControl;

  /// Whether the server currently has a now-playing item for the session.
  final bool isPlaying;

  final String? applicationVersion;

  /// Reads one session record, or `null` if it is missing anything that
  /// makes a session addressable.
  static JellyfinSessionDto? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = _string(raw['Id']);
    final deviceId = _string(raw['DeviceId']);
    final userId = _string(raw['UserId']);
    if (id == null || deviceId == null || userId == null) return null;
    return JellyfinSessionDto(
      id: id,
      deviceId: deviceId,
      deviceName: _string(raw['DeviceName']) ?? 'Unknown device',
      client: _string(raw['Client']) ?? '',
      userId: userId,
      supportsRemoteControl: raw['SupportsRemoteControl'] == true,
      isPlaying: raw['NowPlayingItem'] is Map,
      applicationVersion: _string(raw['ApplicationVersion']),
    );
  }

  /// Whether this session is another Jellyfinity install signed in as
  /// [userId], and therefore a candidate peer.
  ///
  /// Both halves matter. The client check is what keeps a Jellyfin web
  /// tab or a third-party app out of a picker that offers to transfer a
  /// Jellyfinity queue to it, and the user check is the account-isolation
  /// invariant applied at the earliest point it can be: an administrator
  /// signed in here can see every session on the server, and `/Sessions`
  /// will happily return all of them.
  bool isJellyfinityPeerOf(String userId) =>
      this.userId == userId && client == clientName;

  DeviceObservation toObservation({required String localDeviceId}) =>
      DeviceObservation(
        deviceId: deviceId,
        sessionId: id,
        name: deviceName,
        supportsRemoteControl: supportsRemoteControl,
        isPlaying: isPlaying,
        isThisDevice: deviceId == localDeviceId,
      );

  /// The `Client` value a Jellyfinity session reports — the same constant
  /// `JellyfinClientIdentity` sends on every request.
  static const String clientName = 'Jellyfinity';

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
