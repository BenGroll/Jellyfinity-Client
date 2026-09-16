import 'package:equatable/equatable.dart';

import 'ConnectedPlaybackLimits.dart';
import 'DeviceCapabilities.dart';
import 'remote_command_kind.dart';

/// What one Jellyfinity install says about itself to its peers — the body
/// of an `EnvelopeKind.presence` message.
///
/// It exists because Jellyfin's own session record cannot carry it.
/// `/Sessions` reports a client name, a device name, an application
/// version and a fixed `GeneralCommandType` list; there is no free-form
/// field a client may define, and `ClientCapabilities` validates
/// everything it accepts against a server-side enum. Smuggling a
/// Jellyfinity protocol version into `AppStoreUrl` or a capability set
/// into `PlayableMediaTypes` would make the server's own device list
/// wrong in order to make Jellyfinity's right.
///
/// So Jellyfin answers "which sessions exist, and are they mine" — the
/// question only the server can answer — and the peers answer "what am I,
/// and what will I accept" themselves, in their own vocabulary, over the
/// channel the server relays. The protocol version is not repeated here:
/// it is already on the envelope carrying this, checked before the
/// payload is read at all (`ConnectedPlaybackEnvelope.decode`).
///
/// [platform] is the one field that is neither identity nor capability.
/// It is here for the duplicate-name problem: two installs both called
/// "Living Room" are indistinguishable in a picker, and the listener's
/// own words are the only ones Jellyfinity may put on screen beside them
/// — "Living Room (Fire TV)" and "Living Room (Windows)" are useful,
/// "Living Room (2)" is not.
class DeviceAdvertisement extends Equatable {
  const DeviceAdvertisement({
    required this.deviceId,
    required this.name,
    required this.capabilities,
    this.platform,
    this.isPlaying = false,
    this.nowPlayingTitle,
    this.nowPlayingArtist,
  });

  /// The peer's stable install identity — see `ConnectedDevice.deviceId`.
  /// Sent rather than inferred from the session, because a session id is
  /// the thing that changes and this is the thing that does not.
  final String deviceId;

  /// The friendly name the peer advertises for itself.
  final String name;

  final DeviceCapabilities capabilities;

  /// A short platform word — `Windows`, `Android`, `Fire TV`, `iOS`.
  /// Never parsed into behaviour: capabilities say what a device will do,
  /// and this only ever becomes text beside a duplicate name.
  final String? platform;

  /// Whether the peer is producing audio for this profile right now.
  final bool isPlaying;

  /// The current track's display metadata. These are intentionally plain
  /// strings: presence must not carry media tokens, URLs or server-local
  /// identifiers.
  final String? nowPlayingTitle;
  final String? nowPlayingArtist;

  Map<String, Object?> toPayload() => {
    'deviceId': deviceId,
    'name': name,
    'canPlay': capabilities.canPlay,
    'canControl': capabilities.canControl,
    'commands': [
      ...capabilities.acceptedCommands.map((kind) => kind.wireName),
      ...capabilities.unknownCapabilities,
    ]..sort(),
    'maxQueueEntries': capabilities.maxQueueEntries,
    if (platform != null) 'platform': platform,
    'playing': isPlaying,
    if (nowPlayingTitle != null && nowPlayingTitle!.isNotEmpty)
      'nowPlayingTitle': nowPlayingTitle,
    if (nowPlayingArtist != null && nowPlayingArtist!.isNotEmpty)
      'nowPlayingArtist': nowPlayingArtist,
  };

  /// Reverses [toPayload]. Returns `null` only when the two fields that
  /// cannot be guessed at are missing; everything else degrades to a
  /// conservative default, because a peer that advertises itself badly
  /// should appear as a device that accepts nothing rather than as no
  /// device at all.
  ///
  /// Command names this build does not know are kept in
  /// [DeviceCapabilities.unknownCapabilities] rather than dropped — a
  /// newer peer's extra capability survives being looked at by an older
  /// one.
  static DeviceAdvertisement? tryDecode(Map<String, Object?> payload) {
    final deviceId = payload['deviceId'];
    final name = payload['name'];
    if (deviceId is! String || deviceId.isEmpty) return null;
    if (name is! String || name.isEmpty) return null;

    final accepted = <RemoteCommandKind>{};
    final unknown = <String>[];
    final commands = payload['commands'];
    if (commands is List) {
      for (final raw in commands) {
        final kind = RemoteCommandKind.tryParse(raw);
        if (kind != null) {
          accepted.add(kind);
        } else if (raw is String && raw.isNotEmpty) {
          unknown.add(raw);
        }
      }
    }

    final maxEntries = payload['maxQueueEntries'];
    final platform = payload['platform'];
    return DeviceAdvertisement(
      deviceId: deviceId,
      name: name,
      platform: platform is String && platform.isNotEmpty ? platform : null,
      isPlaying: payload['playing'] == true,
      nowPlayingTitle: _optionalText(payload['nowPlayingTitle']),
      nowPlayingArtist: _optionalText(payload['nowPlayingArtist']),
      capabilities: DeviceCapabilities(
        canPlay: payload['canPlay'] == true,
        canControl: payload['canControl'] == true,
        acceptedCommands: accepted,
        // A peer may advertise a smaller bound than this build enforces,
        // never a larger one: the sender is the one that has to hold the
        // queue in memory, but the receiver is the one that has to
        // accept it.
        maxQueueEntries: maxEntries is int && maxEntries > 0
            ? (maxEntries < ConnectedPlaybackLimits.maxQueueEntries
                  ? maxEntries
                  : ConnectedPlaybackLimits.maxQueueEntries)
            : ConnectedPlaybackLimits.maxQueueEntries,
        unknownCapabilities: unknown,
      ),
    );
  }

  static String? _optionalText(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  @override
  List<Object?> get props => [
    deviceId,
    name,
    capabilities,
    platform,
    isPlaying,
    nowPlayingTitle,
    nowPlayingArtist,
  ];
}
