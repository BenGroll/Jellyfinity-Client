import 'dart:io';

import 'package:flutter/foundation.dart';

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
/// build capable of finishing a transfer. [RemoteCommandKind.appendToQueue]
/// stays out: nothing composes it yet.
///
/// [RemoteCommandKind.setVolume] joined in v0.6.0, but only where
/// `JustAudioPlaybackEngine.systemVolume` can actually answer — Android
/// and Windows, via their native volume bridges (`MainActivity.kt`,
/// `flutter_window.cpp`). Advertising it on a platform with no bridge
/// would repeat the exact mistake this class's own doc warns against:
/// a controller could compose it, watch it get accepted, and nothing
/// would move. Gated through [debugSystemVolumeSupported] rather than a
/// direct `Platform` check inline so a test can drive both sides of the
/// gate without depending on which host happens to run it — the same
/// seam `ConnectedPlaybackTargetLink.clock`/`.newMessageId` use for
/// platform/time/randomness a test needs to control directly. This is
/// also why [supportedRemoteCommands] is a getter, built fresh on each
/// read, rather than a `final` computed once at first access.
///
/// Notably absent:
/// - [RemoteCommandKind.stop] — not named in this version's scope, and
///   `PlaybackCubit` has no "stop but keep the queue" action to call.
DeviceCapabilities get supportedRemoteCommands => DeviceCapabilities(
  canPlay: true,
  canControl: true,
  acceptedCommands: {
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
    if (debugSystemVolumeSupported) RemoteCommandKind.setVolume,
  },
);

/// Whether this build's platform has a real system-volume bridge — see
/// [supportedRemoteCommands]'s doc for why this is a seam rather than an
/// inline `Platform` check. Defaults to the real answer for Android and
/// Windows; a test overrides it directly and must restore it afterwards.
@visibleForTesting
bool debugSystemVolumeSupported = Platform.isAndroid || Platform.isWindows;
