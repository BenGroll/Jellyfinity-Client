import 'package:equatable/equatable.dart';

import '../media/MediaId.dart';
import '../media/MediaImage.dart';
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
    this.nowPlayingImage,
    this.controllingSessionId,
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

  /// An artwork *pointer* for the current track — owning item id, role and
  /// content tag, the same safe shape `RemoteQueueEntry.image` already
  /// uses. Never a URL: the receiver resolves it against its own session,
  /// after rebinding the item id to its local server (`DevicePresenceRegistry`).
  final MediaImage? nowPlayingImage;

  /// The session this device is currently driving, when it is driving
  /// one.
  ///
  /// Control is a relationship between two devices, and until this
  /// existed only the controller knew about it: a device had no way to
  /// discover it was being driven, so two devices could each believe they
  /// were controlling the other. Advertising it makes the relationship a
  /// fact both ends — and every onlooker — can read, which is what lets a
  /// device show that it is being controlled and lets a controller stand
  /// down when its target takes control of something itself.
  final String? controllingSessionId;

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
    if (controllingSessionId != null)
      'controllingSessionId': controllingSessionId,
    if (nowPlayingImage != null)
      'nowPlayingImage': {
        'itemId': nowPlayingImage!.itemId.key,
        'kind': nowPlayingImage!.kind.name,
        'tag': nowPlayingImage!.tag,
        if (nowPlayingImage!.aspectRatio != null)
          'aspectRatio': nowPlayingImage!.aspectRatio,
      },
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
      nowPlayingImage: _decodeImage(payload['nowPlayingImage']),
      controllingSessionId: _optionalText(payload['controllingSessionId']),
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

  static MediaImage? _decodeImage(Object? value) {
    if (value is! Map) return null;
    final itemIdKey = value['itemId'];
    final itemId = itemIdKey is String ? MediaId.tryParse(itemIdKey) : null;
    final tag = _optionalText(value['tag']);
    final kindName = _optionalText(value['kind']);
    if (itemId == null || tag == null || kindName == null) return null;
    MediaImageKind? kind;
    for (final candidate in MediaImageKind.values) {
      if (candidate.name == kindName) kind = candidate;
    }
    if (kind == null) return null;
    final aspectRatio = value['aspectRatio'];
    return MediaImage(
      itemId: itemId,
      kind: kind,
      tag: tag,
      aspectRatio: aspectRatio is num ? aspectRatio.toDouble() : null,
    );
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
    nowPlayingImage,
    controllingSessionId,
  ];
}
