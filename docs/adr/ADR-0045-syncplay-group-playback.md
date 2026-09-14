# ADR-0045: SyncPlay-based group playback

## Status

Accepted (v0.6.0).

## Context

The single-owner arc (ADR-0037 onward) gives a listener exactly one device
or nothing playing at a time, moved deliberately between devices. v0.6.0's
respec adds a second, wider mode Ben described directly: "play on all
devices" — every speaker on the account playing the same thing together,
not a queue handed from one device to the next.

Jellyfin already has a server-side answer to this: **SyncPlay**. A group
of sessions the server tracks; members create, join and leave it; one
queue and one transport state belong to the group; a ping/buffering/ready
exchange keeps members' local clocks close enough that starting the same
file at (almost) the same server timestamp sounds like one room, not an
echo. Building a second, Jellyfinity-specific synchronization protocol
next to it would duplicate exactly what the server already coordinates,
and would not work with any official Jellyfin client already in a
listener's house.

The respec also confirmed something worth building toward on purpose,
without building it now: a later, explicitly deferred "listen together
across accounts" feature would need the same shape — a shared group, one
queue, member join/leave. SyncPlay's groups are already server-scoped,
not account-scoped in the way this app's own device pairing is, so
building on them now does not paint that door shut, provided this app's
group *membership* stays expressed as "devices on this profile," not
baked into SyncPlay's own group semantics.

## Considered

**A client-side relay through the existing envelope protocol** (`RemoteCommand`,
`ConnectedPlaybackTransport`) — one device "hosts," forwarding transport
commands to every other member the way a controller already drives one
target. Rejected: this is exactly a second synchronization protocol, it
requires one member to be a single point of failure the group has no
model for surviving, and it does nothing an official Jellyfin client
(a group member. this app has no control over) could ever join.

**N independent playback streams that each try to catch up to the others
by comparing local position.** Rejected outright — the roadmap says so
explicitly, and it is also just SyncPlay's own job, done worse, twice.

**SyncPlay, but treat it as replacing the single-owner model.** Rejected:
a group is *one more shape of owner*, not a different kind of app. Every
single-device path — auto-detection, takeover, transfer, remote queue and
volume control — must keep working unchanged for a listener who never
opens a group (an explicit v0.6.0 requirement). Group membership widens
"who can be the owner" to "a group, addressed as one," rather than
replacing `ConnectedPlaybackTargetLink`/`PlaybackControlCubit`'s existing
contract.

## Decision

Build group playback on Jellyfin's own SyncPlay REST/WebSocket surface:

- `SyncPlayApi` (`lib/infrastructure/jellyfin/connected/JellyfinSyncPlayApi.dart`)
  wraps `/SyncPlay/New`, `/SyncPlay/Join`, `/SyncPlay/Leave`,
  `/SyncPlay/SetNewQueue`, and the transport actions
  (`Play`/`Pause`/`Seek`/`Buffering`/`Ready`/`Ping`) Jellyfin's SyncPlay
  controller defines. This is REST, not the envelope protocol — a group
  is Jellyfin's concept, not a Jellyfinity-to-Jellyfinity message.
- Group state arrives as `SyncPlayGroupUpdate` frames on the same shared
  WebSocket `JellyfinSessionTransport` already owns (ADR-0038's "Jellyfin
  is the only relay" extended to a second message type on one socket,
  not a second socket).
- `SyncPlayGroupCubit` (`lib/app/connected_playback/SyncPlayGroupCubit.dart`),
  a `@lazySingleton` at the same architectural slot as `PlaybackControlCubit`
  and `ActiveRemotePlaybackWatcher`: it owns this device's membership in at
  most one group, translates `SetNewQueue`/transport `GroupUpdate`s into
  real `PlaybackCubit` calls (the *only* path into local playback, per
  `ConnectedPlaybackTargetLink`'s own precedent), and never touches
  `PlaybackCubit.setSystemVolume` or reads/writes anything volume-shaped —
  the enforcement of the invariant below is "this class has no code path
  that can," not a runtime check.
- The device picker's two leading choices are "play on this device" and
  "play on all devices" (the latter creating or joining a group spanning
  this profile's reachable devices); a member already in a group shows
  that plainly rather than offering to create a second one.
- **Volume never travels with a group.** Every message this cubit sends
  or decodes is queue/transport-shaped only; volume stays exactly where
  v0.6.0's volume work already keeps it: `PlaybackCubit`'s own per-device
  state, read and set through `RemoteCommandKind.setVolume` alone — the
  same invariant `PlaybackTransfer`'s message shapes already uphold for
  an ordinary handoff.
- Joining, leaving, and a join that cannot succeed (SyncPlay disabled on
  this server, or a member the group would not admit) are distinct,
  visible states — never a silent no-op — surfaced whichever screen the
  listener chose from (the device picker, or the Remote destination).
- A member dropping out (a crash, a lost connection) and rejoining later
  uses the same `Join` call against the group id it remembers for this
  scope; the group itself is the server's concern to keep alive, not this
  app's.

## Consequences

- Group playback works with any other official Jellyfin client already in
  the SyncPlay group — this app never has to reimplement compatibility
  with them.
- The later, deferred cross-account listen-together feature has a real
  foundation to extend (a group is already "several sessions with one
  queue"); this ADR does not design that feature, only avoids closing the
  door on it.
- Every single-device connected-playback path — auto-detection (ADR-0044),
  takeover, transfer, remote queue and volume — is untouched by a listener
  who never opens a group, per this decision's own requirement.
- What this slice does **not** attempt: clock-drift correction beyond
  Jellyfin's own `Ping`/`Ready` exchange, and a full audit against every
  `GroupUpdate`/`PlaybackRequest` variant Jellyfin's SyncPlay protocol
  defines. Both are real follow-up work the hardening pass (v0.6.0's own
  testing-matrix items) should exercise against a live server before
  release, not assumed correct from protocol documentation alone.
