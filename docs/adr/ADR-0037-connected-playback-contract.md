# ADR-0037: Connected playback contract

## Status

Accepted

## Context

`Roadmap to v0.6.md`'s v0.5.1 asks for "one testable vocabulary and
ownership model for connected playback **before** network or UI code
depends on it". The arc above it — v0.5.2 through v0.6.0 — builds a
Jellyfin session transport, a device picker, remote Now Playing, and then
completes Windows, Android and the television capability path. All of
that will speak the vocabulary decided here, so anything got wrong here
is wrong in five later releases at once.

The big goal is Spotify Connect's dependability without any of its
infrastructure: a listener sees their Jellyfinity devices, chooses where
sound plays, moves the whole playable queue without restarting the
listening context, and drives the active player from somewhere else.
"Transfer playback" has a strict meaning in that document — the
destination receives the ordered queue, current item, position, shuffle
and repeat, and becomes the *only* owner once it confirms it is ready.
Opening the current song on another device is not a transfer.

Three existing constraints bound the solution:

- `CONTEXT.md`: transport, domain, presentation and persistence models
  stay distinct; widgets never see Jellyfin DTOs; failures are
  normalized; `Server`, `User`, credentials, session, saved account and
  active account are all different things.
- ADR-0013: the queue is Jellyfinity application state, and
  `PlaybackEngine` is a deliberately narrow "play this list" seam.
- ADR-0036: television mode is a capability path, not a second app.

The version is also explicitly scoped to *no* network code. Its
definition of done is that the entire discovery, control, synchronization
and handoff conversation runs "in pure tests without a Flutter widget,
audio backend, or live Jellyfin server".

## Decision: the target is authoritative, and a controller holds a
projection

Only the device producing audio owns the live queue. Every other device
holds a **revisioned projection** of it and may not merge that projection
into its own persisted queue.

The alternative — a shared queue both ends edit, reconciled on conflict —
was rejected on two counts. It needs a merge policy for a data structure
where merges are meaningless (there is no sensible union of "the phone
removed track 4" and "the TV moved track 4"), and it makes the
destructive case the default: a listener who glances at what the TV is
playing would have their own half-finished album overwritten on the
device in their hand. `PlaybackOwnership.ownsLocalQueue` is the single
guard every write to `PlaybackQueue` or `QueueRepository` asks first, and
it is `false` for exactly as long as another device is the player.

Considered and rejected alongside it: making a remote device a second
`PlaybackEngine` implementation. It is superficially attractive —
"playing over there" looks like "playing through a different output" —
but ADR-0013's engine contract is *play this resolved list of local
sources*, and a remote target resolves its own sources, applies its own
quality, normalization and crossfade settings, and can refuse. Squeezing
that into `setSources` would either lie about failure or widen the engine
seam that ADR-0013 deliberately kept narrow.

## Decision: Jellyfin is the relay; there is no second network

Discovery and delivery go through the authenticated Jellyfin server's
session API, remote-control endpoints and WebSocket. No Jellyfinity
account, no cloud service, no mDNS or other local-network discovery, and
no direct device-to-device socket.

This follows `CONTEXT.md`'s "no unnecessary cloud dependency" and
`PHILOSOPHY.md`'s self-hosted promise, and it has a practical payoff: two
devices that can both reach the server can reach each other, including
across subnets and VPNs, which local discovery cannot do. The cost —
connected playback needs the server, so it stops when the server is
unreachable even though local playback does not — is accepted and made
explicit in `ConnectedPlaybackConnection.offline` and
`ConnectedPlaybackFailures.offline()`, whose message says local playback
is unaffected.

## Decision: everything is scoped to one server and one profile

`ConnectedPlaybackScope` (server id + Jellyfin user id) rides on every
device, snapshot, command and envelope, and is checked in
`ConnectedPlaybackEnvelope.decode` before a payload is read.

Scoping is not inherited from "whoever is signed in now" for a specific
reason: a message can outlive an account switch, and Jellyfin grants
administrators visibility of every session on the server. The server's
answer to "what may you control" is not Jellyfinity's answer to "what is
this listener's session". Enforcing it at the decoder rather than in each
handler means account isolation cannot be forgotten in one place.

`JellyfinAccount.id` is deliberately not the key: two saved accounts can
point at the same user on the same server, and those are the same
devices.

## Decision: two-part device identity

`ConnectedDevice` carries both a stable `deviceId` (the install identity
`DeviceIdentityStore` already persists) and an ephemeral `sessionId` (the
current Jellyfin session). Commands are addressed to the session, because
that is what the server can route; remembered targets and "my living room
TV" are keyed by the device, because that is what survives a reconnect.
Conflating them produces both obvious bugs at once — an unroutable
command, and a last-used device forgotten on every restart.

Duplicate friendly names get a `nameHint` computed where the duplicate is
*observed*, since a name is only ambiguous relative to the other names on
screen.

## Decision: a versioned envelope with additive tolerance

`ConnectedPlaybackEnvelope` carries `protocolVersion`, `scope`,
`senderSessionId`, `messageId`, `kind` and an opaque `payload`. The
compatibility rule is the ordinary one: same major is compatible, a
different major is incompatible and surfaced (not an error to retry —
one of the two installs must be updated); a newer minor may send kinds,
commands and fields this build has never seen, and each is ignored
individually.

`decode` has no throwing path. Everything it will not act on comes back
as an `IgnoredEnvelope` with a reason, split so that "not for me" is a
log line and "incompatible peer" is something the device list explains.
Self-sent messages are dropped there too — Jellyfin broadcasts to
sessions including the sender, and a device acting on its own commands
would apply every one twice.

## Decision: monotonic revisions, command ids, and receiver-side expiry

- **`StateRevision`** is a per-session counter. A controller takes the
  highest revision it has seen rather than the newest message it
  received, which is the defence against reordering; and a structural
  command names the revision it was composed against, which is what
  serializes competing controllers. Two controllers both saying "remove
  row 4 of revision 12" cannot interleave into something neither asked
  for: the second is refused as stale and resynchronizes.
- **Structural is narrower than "changes state".** Queue mutations and
  `jumpToQueueEntry` are structural. `next`/`previous` are not: "skip
  this" means whatever is playing when it arrives, and a target that
  auto-advanced a second earlier refusing the skip would make the remote
  feel broken at the moment a listener is most likely to press it.
  Duplicates of those are handled by command id, which is the mechanism
  that actually fits them.
- **Command ids, not natural idempotency.** `seek` to 30s is the same
  state however many times it lands; `next` twice costs two songs. Every
  command therefore carries an id and a target keeps a bounded duplicate
  window (`ConnectedPlaybackLimits.commandHistoryLength`), answering a
  replay with the *first* attempt's result — including its revision, so a
  retry leaves the controller exactly where a delivered command would
  have.
- **Expiry is a lifetime, not a deadline.** Two self-hosted devices have
  no reason to agree on the time of day; a Fire TV back from a week
  unplugged has a wrong date. A wall-clock expiry would be permanently
  expired or never expiring on such a peer, and would look like a network
  problem. So a command carries a duration, the receiver stamps arrival
  against its own monotonic `ElapsedClock`, and both ends only ever
  compare two readings of one clock.

Every refusal is a member of `CommandOutcome`, and the test for adding
one is whether the controller should *do* something different about it —
resync, stop offering the control, tell the listener to change a server
permission. `ConnectedPlaybackFailures` is the single place those become
`Failure`s, so the retry decision is made once. `IncompatibleClientFailure`
joins `lib/core/result/failure.dart` for the same reason
`UnsupportedServerFailure` is there: retrying cannot help, and offering a
retry would be a lie — except the thing to update is a client, not the
server both clients share.

## Decision: a handoff is four messages, and the source can always resume

`TransferOffer` → `TransferReadiness` → `TransferCommit` →
`TransferResult`, driven by `PlaybackHandoff` as an explicit state
machine over `TransferStage`.

One message ("play this over there") would have to either stop the source
before knowing whether the target can comply — losing the listener's
music when it cannot — or leave the source playing while it waits, which
is two devices playing at once. Four messages put exactly one uncertain
window in the middle, between commit and result, and give the source a
`HandoffResumeState` captured before it lets go.

The lost-acknowledgement branch resolves toward **the device the listener
is standing next to**: on timeout the source resumes, and if the target's
result turns up late, the resumed source is the one that stops
(`onLateResult`). Briefly hearing music from two rooms and having it
resolve is recoverable; silence with nothing to press is not.

A target refuses *before* the source stops when it cannot reproduce the
queue in full, naming the entries responsible via `UnavailableItem` —
reused from `Partial`, which already carries id, reason and position.
Entries are never silently dropped or reordered: a queue that arrives
quietly three tracks shorter is the failure mode this whole step exists
to prevent.

## Decision: a separate wire model for queue entries

`RemoteQueueEntry` exists rather than sending `QueueEntry` because the
invariant is about *which fields cross the network*: identifiers and
server-addressable metadata only, never credentials, authenticated stream
URLs, download paths, or audio. `QueueEntry` is safe today, but "safe
today" is not a contract — sending it would publish every future field
someone adds to the local queue. A distinct model makes each addition
deliberate, and keeps its encoding in the same file as its field list.

`availability` and `failureMessage` are deliberately not carried: both
are facts about the *source's* device, and a track a phone could not
decode may play perfectly on a desktop.

## Decision: contracts, and pure services behind them

- `lib/domain/connected_playback/` holds the models above plus three
  replaceable contracts — `DevicePresenceSource` (discovery),
  `ConnectedPlaybackTransport` (delivery), `PlaybackHandoffCoordinator`
  (handoff) — and three pure services that contain the logic:
  `RemotePlaybackTarget` (arbitration), `RemotePlaybackController`
  (projection and composition), `PlaybackHandoff` (the state machine).
- `PlaybackQueue` and `PlaybackEngine` are untouched. The target
  maintains the published *snapshot*; v0.5.3 wires accepted commands
  through to `PlaybackCubit`. Keeping "what the network thinks is
  playing" and "what is actually playing" apart is what stops them
  becoming two sources of truth that drift.
- Nothing in this version imports Flutter, `just_audio`, Drift or Dio.

## Tests

`test/domain/connected_playback/` plus deterministic fakes in
`test/support/connected_playback/`:

- `FakeConnectedPlaybackNetwork` is deliberately a *bad* network —
  duplicating, reordering, dropping and holding messages, all without a
  timer. A fake that always delivered once, in order, would satisfy every
  invariant here without testing any of them.
- Messages travel as encoded JSON strings, so every behaviour test is
  also a wire round-trip test.
- `FakeElapsedClock` makes expiry and handoff timeouts exact rather than
  flaky.
- `connected_playback_conversation_test` runs two clients end to end:
  control, duplicate and reordered delivery, a lost acknowledgement,
  competing controllers, a held-past-lifetime command, account
  isolation, the full four-step handoff, and a check that nothing
  resembling a credential or a path reaches the wire.

## Consequences

- v0.5.2 can build the Jellyfin session transport against a contract that
  already has passing tests, rather than discovering the ownership rules
  while debugging a WebSocket.
- Android and Windows are unaffected at this version: nothing here is
  platform-specific, and no existing behaviour changes. The platform
  deliverables land with the transport and UI that follow.
- The bounds in `ConnectedPlaybackLimits` are stated once and enforced by
  both ends, so an over-long queue is refused while the music is still
  playing rather than after the listener has chosen a device.
- `RemotePlaybackTarget` currently owns a snapshot rather than driving
  real playback. That seam is intentional and is closed in v0.5.3; until
  then the class is exercised only by tests.
- No schema change, no new dependency, no UI.
