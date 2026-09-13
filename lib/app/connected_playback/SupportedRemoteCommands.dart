import '../../domain/connected_playback/DeviceCapabilities.dart';
import '../../domain/connected_playback/remote_command_kind.dart';

/// What this build actually executes when another device drives it
/// (v0.5.3), as both a target's arbitration capabilities and the
/// presence advertisement peers see.
///
/// Deliberately narrower than [DeviceCapabilities.fullPlayer]: advertising
/// a command this build cannot yet carry out would let a controller
/// compose it, have it accepted, and watch nothing happen. Every entry
/// here has a real [ConnectedPlaybackTargetLink] execution path against
/// `PlaybackCubit`.
///
/// Notably absent:
/// - [RemoteCommandKind.setQueue], [RemoteCommandKind.appendToQueue],
///   [RemoteCommandKind.removeQueueEntry] and
///   [RemoteCommandKind.moveQueueEntry] — remote queue editing is not
///   part of this version's required deliverables. Excluding [setQueue]
///   also keeps [DeviceCapabilities.canReceiveTransfer] honestly `false`:
///   nothing wires a handoff commit to `PlaybackCubit` until v0.5.4.
/// - [RemoteCommandKind.stop] — not named in this version's scope, and
///   `PlaybackCubit` has no "stop but keep the queue" action to call.
/// - [RemoteCommandKind.setVolume] — no Jellyfinity platform exposes a
///   settable output volume yet, so [RemotePlaybackSnapshot.volume]
///   staying `null` is the honest answer, not a gap.
final DeviceCapabilities supportedRemoteCommands = DeviceCapabilities(
  canPlay: true,
  canControl: true,
  acceptedCommands: const {
    RemoteCommandKind.play,
    RemoteCommandKind.pause,
    RemoteCommandKind.playPause,
    RemoteCommandKind.previous,
    RemoteCommandKind.next,
    RemoteCommandKind.seek,
    RemoteCommandKind.jumpToQueueEntry,
    RemoteCommandKind.setShuffle,
    RemoteCommandKind.setRepeat,
    RemoteCommandKind.requestSnapshot,
  },
);
