# ADR-0038: Device presence and capability transport

## Status

Accepted

## Context

ADR-0037 settled what two Jellyfinity installs say to each other and put
it behind three contracts, deliberately without a line of network code.
`Roadmap to v0.6.md`'s v0.5.2 is the other half: "let compatible
Jellyfinity instances find one another reliably through their shared
Jellyfin server", with a single lifecycle-aware session transport, a
scoped presence read model, bounded-backoff reconnection with a full
resync, and unsupported-server, proxy/WebSocket, authentication,
permission and network failures normalized *independently*.

Reliability here is mostly about a self-hosted server's failure modes
rather than about throughput. Two devices exchange a few messages a
minute; what makes this hard is that a Jellyfin behind a reverse proxy
can answer every REST call perfectly and still never open a WebSocket,
that an administrator's `/Sessions` returns every other person's
sessions, that Jellyfin has no message type a client may define, and
that the device a listener wants is identified by an id that changes
every time it reconnects.

## Decision: Jellyfin answers what exists; the peers answer what they are

Presence is assembled from two sources that neither replaces nor
duplicates the other.

The server answers the question only it can: which sessions exist, which
install each belongs to (`DeviceId` — the same stable id
`DeviceIdentityStore` puts on every request), whose profile it is, and
whether it will route commands to it. That comes from
`GET /Sessions?ControllableByUserId=…` and the socket's `Sessions` push.

The peers answer the question only they can: what protocol version they
speak and which commands they will accept, as an `EnvelopeKind.presence`
message carrying a `DeviceAdvertisement`.

The alternative — deriving capabilities from Jellyfin's own session
record — was rejected because it cannot be done honestly.
`ClientCapabilities` validates everything it accepts against server-side
enums: `SupportedCommands` is `GeneralCommandType`, `PlayableMediaTypes`
is `MediaType`. There is no field for "this client speaks Jellyfinity
protocol 1.0 and accepts `jumpToQueueEntry`". Smuggling that into
`AppStoreUrl` would make Jellyfin's own device list wrong in order to
make Jellyfinity's right, and it would still not survive a peer running
a build that used the field differently.

The visible consequence is that a device passes through
`DeviceReachability.presenceOnly` before it becomes `ready`: known to
exist, not yet known to be usable. That is the honest state and it is
worth showing. Offering a device as ready before it has said what it
accepts is precisely the failure the capability handshake exists to
prevent — a refusal arriving after the listener has already chosen.

## Decision: envelopes ride inside a `GeneralCommand`

Jellyfin will relay an opaque payload between two sessions only inside a
command it already defines. `POST /Sessions/{id}/Command` with
`Name: "SendString"` carries one free-form string, which is exactly an
encoded envelope, and it arrives at the target as a `GeneralCommand`
socket frame.

`SendString` was chosen over `DisplayMessage` because its argument has no
display semantics attached: a client that received one unexpectedly would
put text in a field, not show a wall of JSON to its user. That question is
mostly hypothetical — a command is only ever addressed to a session whose
`Client` is `Jellyfinity`, which is the same filter discovery uses — but
"mostly" is the wrong standard for a message another application might
receive.

Rejected: a Jellyfinity-defined Jellyfin plugin. It would give a clean
message type and it would also mean connected playback stops working the
moment a listener's server does not have the plugin installed, which
inverts the promise that two Jellyfinity installs sharing an ordinary
server can find each other.

## Decision: REST establishes truth, the socket carries changes

Every connect and every reconnect runs the same sequence: publish
capabilities, read `/Sessions` in full, learn this session's own id from
it, *then* open the socket. A reconnect never resumes mid-conversation.

The ordering is not incidental. A command is addressed to a session id,
and this device does not know its own until the server names it — so the
REST read is what makes anything addressable, including this device's own
outgoing messages. And the one thing a dropped socket guarantees is that
both sides' idea of the state is unverified, which is why the arc
requires a full reconciliation rather than a resumption.

While the socket is down, presence is polled over REST on a deliberately
slow timer. It keeps a device listed and honestly labelled rather than
letting it vanish and reappear mid-reconnect. A failed poll does *not*
reschedule the reconnect: letting a fast poll defer a slow reconnect
would mean presence was attempted forever and the socket never was.

## Decision: `dart:io`'s WebSocket, behind a one-method seam

No package. `CONTEXT.md` asks that dependencies "handle substantial
infrastructure work" and not "substitute for trivial local code", and the
whole implementation is twenty lines over `WebSocket.connect`. Every
target Jellyfinity ships to has `dart:io`; the one platform where this
choice would be wrong is web, which Jellyfinity does not target.

`JellyfinSocketConnection` exists so the transport can be tested without
a server, and it is narrow enough — text in, text out, close — that the
fake satisfying it is a `StreamController` and a list rather than a
pretend socket worth doubting.

## Decision: one classifier for both halves' failures

`ConnectedSessionFailureMapper` turns everything into five answers:
offline, unauthenticated, notPermitted, unsupported, unexpected. Five
because each has a different next step for the listener — wait, sign in,
ask the server's owner, change the server or the proxy, report a bug —
and a picker that said "something went wrong" would serve none of them.

REST is the better witness and is trusted for the distinctions that need
one. 401 and 403 both reach the domain as `UnauthorizedFailure` from the
HTTP layer and mean opposite things here, so the status is recovered from
the failure's cause; "sign in again" is the one action that cannot
possibly help a permission problem.

A socket gives far less: `WebSocket.connect` throws the same
`WebSocketException` for a refused upgrade, a rejected token and a server
with no socket at all. What *is* knowable is whether this session has ever
had a working socket, and that answers the listener's actual question. A
socket that worked and dropped is an interruption to reconnect from; a
socket that has never worked against a server whose REST API answers
fine is a reverse proxy that does not forward upgrades — the single most
common way a self-hosted Jellyfin looks healthy and still cannot do this.

Only the two retryable problems get a reconnect. Backoff doubles from two
seconds to a two-minute ceiling and never gives up on them, because a
listener whose Wi-Fi came back should not have to restart the app; the
three that need a person to act are not retried at all, because a loop
that cannot succeed is a busy loop that hides what is actually wrong.

## Decision: rows are keyed by install, and duplicate names are resolved
where they are seen

`DevicePresenceRegistry` keys entries by `deviceId`, never by session id.
A peer that drops and reconnects is the same row with a new address, not
a second row beside a ghost. A row whose session id changed also drops
everything that session said about itself until the new one says it
again: offering a command to a session that never claimed to accept it is
the bug the handshake exists to prevent.

Jellyfinity's default `DeviceName` is `Jellyfinity`, so duplicate names
are not an edge case — they are what a listener with two installs sees
first. The hint prefers the peer's advertised platform ("Fire TV",
"Windows") because it is what the listener would say themselves, and
falls back to the tail of the stable install id where that does not
separate them. Both are stable across readings; a positional number would
change whenever an unrelated device dropped off the list.

The registry is pure — no transport, no timers, no Flutter — against an
injected `ElapsedClock`, which is what makes expiry, reconnection under a
new session id, duplicate naming and account isolation testable without a
server.

## Decision: scope changes tear down rather than reconfigure

`ConnectedPlaybackLink` (in `lib/app`, where `SessionCubit` and
`AppLifecycleState` both live) sees logging out, switching account and
removing the server as one event: the active scope changed. The old scope
is cleared — socket closed, registry discarded, an empty list published —
before the new one is advertised. There is no moment in which a registry
built for one profile is answering the next one's questions.

Leaving the foreground suspends rather than clears: the profile has not
changed, so the roster is still true and is still shown as
`presenceOnly`, and returning costs one REST read rather than a fresh
discovery. `inactive` and `hidden` are ignored — both are transient on
Android and Windows, and dropping the socket for either would cost a
reconnect for nothing.

## Tests

Presence logic is covered as pure domain: multi-device discovery,
duplicate names resolved by platform and by install id, staleness and the
longer drop window, reconnection under a new session id, incompatible and
unpermitted peers, and scope isolation.

The transport is covered against a fake `dio` adapter and a fake socket:
the connect sequence, the presence handshake and its single reply, socket
`Sessions` pushes, another profile's and another client's sessions never
being listed, an out-of-scope message dropped unread, a proxy that will
not upgrade, 401 and 403 told apart, a server below the floor refused
before any request, bounded backoff, polling while the socket is down,
and the lifecycle transitions.

An integration test covers what only a real Jellyfin can answer — that
the capability post, the session query, the socket upgrade and the
general command are accepted as sent. It skips itself unless a server is
configured, so a contributor without one sees a green suite and CI does
not depend on a server being reachable.

## Consequences

- v0.5.3 receives a working delivery channel: `envelopes` already carries
  decoded, in-scope, non-self commands and snapshots, and `sendCommand`
  already correlates an acknowledgement or times out. What those messages
  *mean* is the next version's.
- `JellyfinSessionContext` gained `serverVersion`, so the transport can
  answer "unsupported server" separately from "unreachable server".
- `JellyfinHttpClient` gained `getJsonList`, because a few Jellyfin
  endpoints answer with a bare array and the alternative was for a caller
  to reach past the client to `dio`.
- Android and Windows are both covered without platform-specific code:
  `dart:io` sockets and cleartext (already permitted for `http://`
  servers) work on both. The Android build is verified; Windows shares
  every line of this.
- No schema change, no new dependency, no UI. The device picker that
  shows all of this is v0.5.5.
