Concept: Cross-device Remote tab — Control / Sync / Play on this device
1. What this replaces
The Remote destination that shipped in v0.6.0 lists every device on the profile with a status ("Connecting…", "Idle", "Playing", etc.) and one action, "Play on all devices." That's not what's wanted. The Remote tab should answer one question at a glance: what is playing, on which of my other devices, right now — and offer exactly three things to do about each one. A device with nothing loaded doesn't belong in the list at all.

This reuses existing plumbing (presence, snapshots, the command/envelope channel, SyncPlay groups, explicit takeover) rather than inventing a parallel protocol — the hard parts already exist; what's missing is the relationship/UI layer tying them together.

2. Remote tab visibility rule
List only profile devices that currently have a loaded queue (playing OR paused — "nothing loaded" is what hides a row, not "silent"). This device is never listed. Each row shows device name/icon, current track, play/pause state, progress. No "Idle"/"Connecting"/"Offline" rows — a device that drops off presence while it had something loaded just disappears.

Each row not already in a relationship with this device shows three actions: Control, Sync, Play on this device.

3. Relationship model
At most one active relationship at a time, per this device:


RemoteRelationship = none | controlling(target) | syncing(target, groupId)
Starting a new one ends the previous first; if switching would interrupt local audio, reuse the existing takeover dialog (v0.6.0, RemotePlaybackOwnership) rather than a new one.

Visible and endable from both ends — if A controls/syncs B, B's own Remote tab shows a row for A with its own End Remote Play.

3.1 Control
Audio stays on the target. Nothing about its playback changes.
This device's Now Playing mirrors the target's RemotePlaybackSnapshot — the existing display path (today only driven automatically, idle-only, by ActiveRemotePlaybackWatcher). Control makes that explicit and user-chosen, works even if this device already has a local queue (pause locally first, same as the existing takeover flow reversed), and persists until ended.
Transport actions send RemoteCommands as today — never volume, which stays per-device per the v0.6.0 invariant.
Target's own local controls are never locked out (already true — it's just another PlaybackCubit reacting to commands via ConnectedPlaybackTargetLink).
Multiple controllers on one target is fine (last command wins, as today); no "who else" UI needed for v1.
3.2 Sync
Audio from both, synchronized — existing SyncPlay machinery (JellyfinSyncPlayApi/SyncPlayGroupCubit, ADR-0045), entered from a specific row instead of a generic button.
New piece needed: Jellyfin SyncPlay groups are pull-based — tapping "Sync" on B from A must make B join automatically. Needs a new directed command (e.g. RemoteCommandKind.joinSyncGroup(groupId)) sent over the existing per-session channel so B's SyncPlayGroupCubit.joinGroup fires on receipt.
A third device syncing with either A or B should land everyone in the same group — pairwise entry point into the same n-way group from ADR-0045.
Volume stays excluded from group state, same as everywhere else.
3.3 Play on this device
A pull transfer — mirror image of the existing push-based takeover: (1) read B's current snapshot (queue+position, already available via Control's mirroring path), (2) send B stop/pause, (3) adopt the queue locally via the same adoptTransferredQueue(...) entry point SyncPlayGroupCubit already uses.
No lasting relationship survives completion — this device just plays its own queue afterward. End Remote Play here is really a cancel for the brief in-flight window, moot once the transfer lands.
4. End Remote Play
Mode	Effect
Control	Stop mirroring/commanding B; B is untouched, keeps playing.
Sync	Leave the group (SyncPlayGroupCubit.leave()); this device keeps playing solo from the shared position; rest of group undisturbed.
Play on this device	Cancel while in flight; no-op/hidden once complete.
5. Reuse map
List/snapshot data: DevicePresenceSource, ConnectedDevice, RemotePlaybackSnapshot.
Control: PlaybackControlCubit, ConnectedPlaybackTargetLink, RemoteCommand/RemoteCommandKind — fully built; just needs an explicit per-device entry/exit instead of ActiveRemotePlaybackWatcher's automatic-only binding.
Sync: JellyfinSyncPlayApi, SyncPlayGroupCubit, ADR-0045 — needs only the new join-request command.
Transfer: PlaybackHandoffCoordinator/explicit-takeover dialog for the push direction; reuse adoptTransferredQueue for this pull direction instead.
Volume: unchanged from v0.6.0 — per-device only, never in a snapshot/transfer/group, in any of the three modes.
6. Actually new work
Remote tab UI: filter + three-action row.
A RemoteRelationship cubit enforcing "at most one relationship, either kind" — neither existing cubit knows about the other today.
RemoteCommandKind.joinSyncGroup(groupId) and its handling.
Reverse-direction snapshot pull for "Play on this device."
Symmetric relationship visibility + End Remote Play on the target's own tab.
7. Open questions to flag to the implementer
Does Control's mirrored Now Playing replace the mini-player app-wide, or only within the Remote tab's detail view? (Doc assumes app-wide, matching current ActiveRemotePlaybackWatcher behavior.)
If B is already synced with C and A taps Sync on B, does A join the existing group (assumed) or get refused?
Should a device mid-transfer be interruptible by a third device's Control/Sync request, or briefly hidden from other devices' lists until it settles?