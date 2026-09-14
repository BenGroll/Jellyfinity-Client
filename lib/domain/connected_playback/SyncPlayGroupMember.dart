import 'package:equatable/equatable.dart';

/// One member of a SyncPlay group, as the server names them (v0.6.0,
/// ADR-0045) — deliberately just a session id and a display name.
/// Whether a member is reachable, playing, or this device is
/// `ConnectedDevice`'s question for the ordinary presence roster; a
/// SyncPlay group is Jellyfin's own concept and does not carry that.
class SyncPlayGroupMember extends Equatable {
  const SyncPlayGroupMember({
    required this.sessionId,
    required this.displayName,
  });

  final String sessionId;
  final String displayName;

  @override
  List<Object?> get props => [sessionId, displayName];
}
