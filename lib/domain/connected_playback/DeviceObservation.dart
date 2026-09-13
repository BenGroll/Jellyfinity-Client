import 'package:equatable/equatable.dart';

/// One sighting of a session, as the *server* describes it.
///
/// Deliberately poorer than [ConnectedDevice]: it carries only what
/// Jellyfin can tell one client about another — which sessions exist,
/// which install each belongs to, what it calls itself, whether the
/// server will route commands to it, and whether it is playing something
/// right now. It knows nothing about protocol versions or Jellyfinity
/// capabilities, because Jellyfin does not.
///
/// It exists so `DevicePresenceRegistry` can be a pure object with no
/// opinion about DTOs. The infrastructure maps a Jellyfin session record
/// to one of these; everything above works in the domain's own words.
/// That is also what lets the presence tests cover duplicate names,
/// expiry and account isolation without a server or a socket.
class DeviceObservation extends Equatable {
  const DeviceObservation({
    required this.deviceId,
    required this.sessionId,
    required this.name,
    this.supportsRemoteControl = true,
    this.isPlaying = false,
    this.isThisDevice = false,
  });

  /// The install this session belongs to (Jellyfin's `DeviceId`, which is
  /// the id Jellyfinity reports on every request).
  final String deviceId;

  /// The session's ephemeral id — what a command is addressed to.
  final String sessionId;

  /// The device name the session reports.
  final String name;

  /// Whether the server will relay commands to this session at all. A
  /// session that says no is a real device the listener owns, not an
  /// error: it is listed and never offered.
  final bool supportsRemoteControl;

  /// Whether the session is playing something right now, per the server.
  ///
  /// The server's answer, not the peer's: it is what makes a device that
  /// has not yet advertised itself still show as the one making noise.
  final bool isPlaying;

  /// Whether this session is this very device, seen in the server's own
  /// list.
  final bool isThisDevice;

  @override
  List<Object?> get props => [
    deviceId,
    sessionId,
    name,
    supportsRemoteControl,
    isPlaying,
    isThisDevice,
  ];
}
