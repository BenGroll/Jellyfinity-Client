# ADR-0040: Remote Now Playing and queue controls

## Status

Accepted

## Context

`Roadmap to v0.6.md`'s v0.5.6 asks Jellyfinity to bind the mini-player, Now
Playing and the queue to either local `PlaybackCubit` state or a chosen
remote device's projection, "through one presentation contract" — and to
"never overwrite the controller's dormant local queue with the remote
queue." ADR-0039 (v0.5.5) deliberately stopped short of this: the device
picker only ever chose a *transfer* destination, and its own doc named
this version as the one that "first constructs a
`ConnectedPlaybackControllerSession` for a chosen device and binds it into
the mini-player/Now Playing/queue."

Everything that session needs already existed: `RemotePlaybackController`
and `RemotePlaybackSnapshot` (v0.5.1, pure domain), and
`ConnectedPlaybackControllerSession` (v0.5.3, app layer) — constructed
nowhere in the app, since nothing before this version chose a device to
drive continuously.

## Decision: a `@lazySingleton` chooses the device, not a screen-scoped cubit

`PlaybackControlCubit` (`lib/app/connected_playback/PlaybackControlCubit
.dart`) owns the one `ConnectedPlaybackControllerSession` this device may
be driving at a time, the same architectural slot `ConnectedPlaybackTargetLink`
already occupies for the target side: whichever device the listener
picked has to stay controlled while they navigate between the mini-player,
Now Playing and the queue screen, not just while one sheet is open.
`DevicePickerCubit` (screen-scoped, per ADR-0039) gained this as a fourth
dependency and now exposes `control`/`stopControlling`, delegating
straight through and mirroring the chosen device's session id in its own
state for the picker's "Controlling — tap to stop" row.

The device picker's row action follows naturally from what was already
there: a device that `isPlaying` and `canBeControlled` is offered
`control` instead of the existing `transferTo`/`bringBackToThisDevice`
actions — sending this device's own queue *to* something already playing
elsewhere is a different, lower-value action than watching and driving
what it already has, and offering both at once on one row would need a
second affordance for a case the roadmap does not ask this version to
solve.

## Decision: the queue is displayed as a `PlaybackQueue`, never as one

`PlaybackControlCubit` projects each arriving `RemotePlaybackSnapshot`
into a display-only `PlaybackQueue`, built exactly the way
`PlaybackCubit.adoptTransferredQueue` already builds one from a handoff's
resolved tracks: the snapshot's `queue` is already in play order (its own
doc says so), so that order is pinned in place with
`PlaybackQueue.withRestoredShuffleOrder` rather than left for a fresh
`withEntries` call to reshuffle. This projection is read-only and lives
only in `PlaybackControlState`; it is never written to `QueueRepository`
and `PlaybackCubit`'s own queue is never touched while controlling —
`PlaybackOwnership.ownsLocalQueue`'s invariant, restated for the
presentation layer instead of the wire layer this time.

Reusing `PlaybackQueue` bought back nearly all of `QueueEditor`'s existing
UI for free. It was generalized from taking a concrete `PlaybackCubit` to
taking a `PlaybackQueue` plus three callbacks (`onJumpTo`, and nullable
`onReorder`/`onRemove`) — local call sites pass all three,
`PlaybackControlCubit`'s remote view passes only `onJumpTo`, since
incremental remote queue editing (`appendToQueue`/`removeQueueEntry`/
`moveQueueEntry`) is still not part of any version's required
deliverables per `SupportedRemoteCommands`'s own doc. A `null` callback
hides that row's affordance (drag handle, remove button) entirely rather
than showing it disabled — "disable or omit unsupported controls
consistently" from the roadmap, and the same convention `RemotePlaybackController
.availableCommands` already uses at the transport-row level.

## Decision: local first, remote branch, never merged

Every one of `MiniPlayer`, `NowPlayingPage` and `QueuePage` now reads
`PlaybackControlCubit` first (`bloc: getIt<PlaybackControlCubit>()`,
matching how `TrackSourceInfoCubit`/`NowPlayingDetailsCubit`/
`DevicePickerCubit` are already resolved outside the constructor-injected
cross-cutting cubits `JellyfinityApp` provides). While
`PlaybackControlCubit.state.isControlling`, each screen renders a
dedicated remote branch (`_RemoteMiniPlayer`, `_RemoteNowPlayingContent`,
`_RemoteQueuePage`) built against `PlaybackControlState` alone; otherwise
every existing local branch is unchanged. This is deliberately two
branches rather than one merged model: the two states genuinely differ in
what they can do (queue editing, source-quality info, hardware media
keys) and forcing them through one shape would either lose those
local-only features or grow a `PlaybackUiState` full of remote-only
fields nothing local ever populates.

Favorite/download state and the artist/album links stay resolved against
this device's own profile by feeding the remote entry's `id` — the
projection's one server-addressable field — into the same
`NowPlayingDetailsCubit` the local branch already uses, rather than
trusting anything the projection carries about them. Source-quality info
(`TrackSourceInfoCubit`) is omitted entirely in the remote branch: it
describes *this* device's own resolved audio source, which does not
exist while another device is the one playing.

`_RemoteNowPlayingContent` is one centered layout at every width, not
`_WidePlayer`'s two-column desktop treatment: remote control is a
secondary surface next to local playback, and "the same confidence as
local Now Playing" is about the control surface being complete and
explicit — every state named, every supported command reachable — not
about matching local's layout pixel for pixel. System media
keys/hardware transport (`JellyfinityApp`'s `CallbackShortcuts`) stay
bound to local `PlaybackCubit` only; the roadmap already names system
media controls a v0.5.7-v0.5.9 platform-rollout concern.

## Decision: six states, one connection field

`PlaybackControlConnection` (`synced` / `resynchronizing` / `reconnecting`
/ `targetEnded`) sits beside `pendingCommand` and `commandError` on
`PlaybackControlState`, together covering every state the roadmap names:
pending (a command in flight), applied (state simply updates), rejected/
timed out (`commandError`, transient like `PlaybackUiState.lastFailure`),
reconnecting and target-ended. `_onDevices` maps `DeviceReachability`
directly onto them: `presenceOnly`/`stale`/`offline` are `reconnecting`
(transient — the picker's own vocabulary already treats them as such);
`incompatible`/`notPermitted` are `targetEnded` (permanent for this
pairing, `DeviceReachability`'s own doc); the device disappearing from
presence entirely is also `targetEnded`. A same-device reconnect under a
new session id calls `ConnectedPlaybackControllerSession.retarget` and
requests a fresh snapshot — revisions are per-session, so the old
projection means nothing against the new one.

Position while remote is extrapolated from the last snapshot using this
device's own clock, exactly as `RemotePlaybackSnapshot.position`'s own
doc describes for a controller — a plain one-second `Timer.periodic`
while `state.isPlaying`, started and stopped by `_updateTicker` rather
than left running once the target pauses or control stops. A `seek`
updates the displayed position optimistically before the command is even
sent; the roadmap's own words for this ("acknowledged target state
corrects optimistic motion, especially seek position") are why only seek
gets this treatment — a queue-editing command's effect is shown by its
row transitioning once the next snapshot arrives, not by guessing a new
queue shape client-side.

## Tests

`test/app/connected_playback/playback_control_cubit_test.dart` drives a
real `ConnectedPlaybackTargetLink`/`PlaybackCubit` pair over
`FakeConnectedPlaybackNetwork` — the same harness v0.5.3-v0.5.5's own
tests already trust — proving snapshot retrieval, capability negotiation,
pending/applied/rejected command states, presence-driven reconnect and
target-ended transitions, and that this device's own local playback is
never touched while controlling. `test/features/playback/device_picker_cubit_test.dart`
gained two tests for `DevicePickerCubit.control`/`stopControlling`'s
delegation. `test/features/playback/remote_now_playing_test.dart` drives
`PlaybackControlCubit`'s state directly (`emit` is `@protected`, not
private — the ordinary way a bloc test seeds a state without re-running
the whole wire protocol) to prove MiniPlayer/NowPlayingPage/QueuePage
render every connection state, disable a command the target does not
advertise, hide reorder/remove entirely, and revert cleanly to local
state on `stop()`; command *effects* against a real target remain the
cubit-level test's job, since nothing here backs a live
`ConnectedPlaybackControllerSession`.

## Consequences

- `stop`, `setVolume`, `appendToQueue`, `removeQueueEntry` and
  `moveQueueEntry` remain unadvertised and unsupported end to end — this
  version changes nothing about what `SupportedRemoteCommands` accepts,
  only what the UI does with the commands already accepted.
- System media controls (notification/lock-screen transport, hardware
  media keys driving a remote target) remain out of scope, deferred to
  the v0.5.7-v0.5.9 platform-completion versions the roadmap already
  names for them.
- No schema change, no new wire message, no dependency.
