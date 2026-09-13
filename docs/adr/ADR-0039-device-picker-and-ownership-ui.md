# ADR-0039: Device picker and ownership UI

## Status

Accepted

## Context

`Roadmap to v0.6.md`'s v0.5.5 asks for a device action on the mini-player
and Now Playing that names the active device, a picker that shows "This
device" plus every compatible Jellyfinity install, and lets the listener
"transfer playback or bring it back to this device" — without claiming
platform completion or binding Now Playing/the queue to a remote
projection (that is v0.5.6).

v0.5.1-v0.5.4 already built the whole foundation this UI sits on:
`DevicePresenceSource` (discovery), `ConnectedPlaybackTargetLink`
implementing `PlaybackHandoffCoordinator.transferTo` (the source side of a
handoff), and `ConnectedPlaybackControllerSession` (driving a chosen
remote target — not yet constructed anywhere, since nothing before this
version chose one). Two things in that foundation shape what the picker
can honestly offer:

- `ConnectedDevice.canReceiveTransfer` is `!isThisDevice && ...` — a
  device may never be offered as a transfer target for *itself*.
- `PlaybackHandoffCoordinator.transferTo` hands over *the caller's own*
  local queue. It has no remote-triggered counterpart: nothing lets one
  device ask another, over the wire, to start a handoff. ADR-0037 chose
  that deliberately — "only a device producing audio owns the
  authoritative live queue" — and a message that could make a *different*
  device suddenly decide to let go of its audio would be exactly the kind
  of remote-initiated ownership change that invariant rules out.

So "bring it back to this device" cannot be `transferTo` run in reverse
by remote control; the two capabilities above make sure of that.

## Decision: "bring it back to this device" is a local resume, not a handoff

A handoff's source only ever *pauses* local playback
(`ConnectedPlaybackTargetLink._applyDecision`'s `stopLocalPlayback` never
tears the queue down). So a device that previously sent its queue away
still has that same queue sitting there, paused, for as long as nothing
else needs it back. "Bring it back to this device" is exactly resuming
it — an ordinary `PlaybackCubit.play()`, already safe to call whether or
not anything is really paused-and-idle elsewhere.

This can transiently show two devices both producing audio — the exact
moment `ConnectedDevice.isPlaying`'s own doc already accepts: "a moment
where two devices claim it is exactly the symptom a handoff is supposed
to make visible rather than hide." The picker does not prevent that
moment or try to force the other device to stop first; it shows both
rows' true state and lets the listener finish the move themselves (stop
the other device however they normally would), rather than inventing a
new remote-initiated ownership message purely to paper over a case the
existing model already tolerates.

The alternative considered — a controller resolves the remote target's
current queue via `ConnectedPlaybackControllerSession`, tells it to
`stop`, and adopts the resolved tracks locally — was rejected for this
version. It would need `stop` promoted from "modeled but never
advertised" (`SupportedRemoteCommands` excludes it on purpose today) to a
real, executed command, and a controller session constructed before this
version otherwise needs one (v0.5.6). That is a real command-execution
change, not a UI change, and belongs with the version that actually binds
remote control into the UI.

## Decision: the picker reads presence directly; no controller session yet

`ConnectedDevice` already carries everything the picker's own vocabulary
needs — `reachability` (mapped to available/connecting/stale/
incompatible/permission-denied/unavailable), `isPlaying` (active), and
`isThisDevice`. `DevicePickerCubit` (`lib/features/playback/presentation
/device_picker_cubit.dart`) is built directly against `DevicePresenceSource`
and `ConnectedPlaybackTargetLink`; it never constructs a
`ConnectedPlaybackControllerSession`. That class's own doc already named
this version as "the picker" that would first choose a device — this ADR
narrows that to choosing a *transfer destination*, not yet a live
controller target. Binding a chosen device into an ongoing controller
session, and into Now Playing/the queue, is v0.5.6's job.

## Decision: expose what the picker needs, nothing wire-shaped

Two small additions make the existing foundation reachable from
presentation code without changing what crosses the wire:

- `DevicePresenceSource` joins `ConnectedPlaybackTransport` as a second
  interface `ConnectedPlaybackTransportModule` binds onto the one live
  `JellyfinSessionTransport` singleton, for the same reason the module
  already gives — one connection, never two independently constructed
  transports racing to open the same socket.
- `ConnectedPlaybackTargetLink.localSnapshot` is a new, ordinarily-public
  getter alongside the existing `@visibleForTesting snapshot` — this
  device's own current snapshot, which `transferTo` needs but a caller
  outside a test has had no way to obtain until now.

Neither changes `ConnectedPlaybackEnvelope`, `RemoteCommandKind`, or any
other wire-level type from v0.5.1-v0.5.4.

## Tests

`test/features/playback/device_picker_cubit_test.dart` drives two real
`ConnectedPlaybackTargetLink`s over `FakeConnectedPlaybackNetwork` (the
same harness v0.5.4's own tests use) to prove a transfer actually moves
ownership end to end, alongside presence ordering, connection-state
tracking, scope isolation on sign-out, and the local-resume path.
`test/features/playback/device_picker_widget_test.dart` covers the device
action's presence on the mini-player and Now Playing, the picker's
content at compact phone, windowed desktop, and television-scale
constraints, and the "no other devices" and remote-device-with-a-reason
states. `test/support/connected_playback/FakeDevicePresenceSource.dart`
is a new, hand-driven fake for both.

## Consequences

- v0.5.6 (remote Now Playing and queue controls) is the version that
  first constructs a `ConnectedPlaybackControllerSession` for a chosen
  device and binds it into the mini-player/Now Playing/queue; this
  version only remembers presence and moves ownership.
- `stop` remains unadvertised in `SupportedRemoteCommands`. Promoting it
  — and building the resolve-then-stop-then-adopt path this ADR
  considered and deferred — is available to a later version if a
  controller-initiated reclaim ever becomes required; nothing here
  forecloses it.
- No schema change, no new wire message, no dependency.
