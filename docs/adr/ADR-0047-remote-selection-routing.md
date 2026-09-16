# ADR-0047: Remote selection routing

- Status: Accepted (v0.6.0)
- Date: 2026-09-16

## Context

A local library selection can be made on either side of a single-device
Remote Play connection. Treating that selection as a local takeover stops the
controlled device and detaches the controller, which contradicts the expected
model: the selection should behave as though it happened on the device that
produces audio. The same interaction in a SyncPlay group must update the
shared queue for every member.

## Decision

`PlaybackCubit` asks the narrow `RemotePlaybackOwnership` seam to redirect a
selection before touching its local engine. `PlaybackControlOwnership` chooses
in this order:

1. a joined `SyncPlayGroupCubit`, which sends the tapped queue through
   SyncPlay and waits for the normal group queue update to adopt it locally;
2. the active `PlaybackControlCubit`, which sends a revisioned `setQueue`
   command to the controlled target;
3. local playback when neither remote destination applies.

The remote command carries the resolved queue shape, selected start index,
shuffle/repeat state, origin name, and start-playing intent. The controller
optimistically projects the new queue and rolls that projection back when the
command is rejected. Remote control remains attached; explicit end-control or
group leave operations are the only detach paths.

The ownership implementation resolves SyncPlay lazily because injecting it
would create a dependency cycle: `PlaybackCubit` depends on ownership while
`SyncPlayGroupCubit` depends on `PlaybackCubit`.

## Consequences

- Tapping a song, album, or artist while controlling another device changes
  that device's active queue without producing a second local stream.
- A SyncPlay selection is applied by the server's group update path, keeping
  every member on the same queue and preserving the existing single local
  playback adoption path.
- Remote selection failures remain visible in the controller state, while the
  local queue is not silently mutated as a fallback.
