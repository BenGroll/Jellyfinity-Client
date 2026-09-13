import '../../domain/connected_playback/DeviceCapabilities.dart';
import '../../domain/connected_playback/remote_command_kind.dart';

/// What this build actually executes when another device drives it
/// (v0.5.3) or hands it a queue outright (v0.5.4), as both a target's
/// arbitration capabilities and the presence advertisement peers see.
///
/// Deliberately narrower than [DeviceCapabilities.fullPlayer]: advertising
/// a command this build cannot yet carry out would let a controller
/// compose it, have it accepted, and watch nothing happen. Every entry
/// here has a real [ConnectedPlaybackTargetLink] execution path against
/// `PlaybackCubit`.
///
/// [RemoteCommandKind.setQueue] joined in v0.5.4: it is the command a
/// handoff commits with (`SetQueueCommand`'s own doc), so leaving it out
/// would make [DeviceCapabilities.canReceiveTransfer] false on every
/// build capable of finishing a transfer. [RemoteCommandKind.appendToQueue],
/// [RemoteCommandKind.removeQueueEntry] and
/// [RemoteCommandKind.moveQueueEntry] stay out: incremental remote queue
/// editing is still not part of any version's required deliverables.
///
/// Notably absent:
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
    RemoteCommandKind.setQueue,
    RemoteCommandKind.removeQueueEntry,
    RemoteCommandKind.moveQueueEntry,
    RemoteCommandKind.requestSnapshot,
  },
);
