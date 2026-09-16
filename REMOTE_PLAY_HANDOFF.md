# Remote playback handoff

This is the working architecture guide for Jellyfinity cross-device playback.
Read it before changing Remote, connected playback, handoff, or SyncPlay code.
It describes the seams and invariants needed to diagnose a device interaction
without first tracing the whole application.

## Product model

Remote playback has three distinct modes:

- **Control**: this device is a controller and another device owns its active
  queue and produces audio. The mini-player and Now Playing screen say
  `Playing on <device>`.
- **Transfer**: the source queue, current index, position, repeat/shuffle, and
  playing state move to this device. The source pauses only after the target
  has a usable queue.
- **Sync**: Jellyfin SyncPlay owns the synchronized group. It is separate from
  Jellyfinity's envelope protocol and must not be confused with controlling a
  peer's queue.

The Remote screen is the user-facing device picker. The device icon in the
mini-player routes to that screen; it must not resurrect the obsolete device
picker sheet.

## Architecture map

| Responsibility | Main code |
| --- | --- |
| Bring the signed-in device online and track lifecycle | `lib/app/connected_playback/ConnectedPlaybackLink.dart` |
| Maintain this device's local target and execute commands | `lib/app/connected_playback/ConnectedPlaybackTargetLink.dart` |
| Controller state and remote command composition | `lib/app/connected_playback/PlaybackControlCubit.dart` and `ConnectedPlaybackControllerSession.dart` |
| Local queue → remote snapshot projection | `lib/app/connected_playback/RemoteQueueProjection.dart` |
| Device list, WebSocket, presence, envelopes, acknowledgements | `lib/infrastructure/jellyfin/connected/JellyfinSessionTransport.dart` |
| REST capabilities, sessions, command delivery, socket URL | `lib/infrastructure/jellyfin/connected/JellyfinSessionApi.dart` |
| Strict wire envelope and early safety checks | `lib/domain/connected_playback/ConnectedPlaybackEnvelope.dart` |
| Scope: local repository ID plus cross-install wire identity | `lib/domain/connected_playback/ConnectedPlaybackScope.dart` and `ConnectedPlaybackScopeOf.dart` |
| Queue/command/transfer wire codecs | `RemoteQueueEntry.dart`, `RemoteCommand.dart`, `PlaybackTransfer.dart`, `RemotePlaybackSnapshot.dart` |
| Jellyfin-native SyncPlay groups | `lib/app/connected_playback/SyncPlayGroupCubit.dart`, `lib/infrastructure/jellyfin/connected/JellyfinSyncPlayApi.dart` |
| Remote UI | `lib/features/remote/presentation/RemotePage.dart` |
| Local diagnostic screen | `lib/features/logs/presentation/LogsPage.dart` |

## Startup and presence protocol

Every signed-in app starts both links in `bootstrap.dart`:

1. `ConnectedPlaybackLink.start()` advertises capabilities, reads the
   controllable session roster, opens Jellyfin's WebSocket, and observes app
   lifecycle.
2. `ConnectedPlaybackTargetLink.start()` subscribes to incoming envelopes and
   publishes a snapshot whenever local playback changes.
3. The transport sends a `presence` envelope to every Jellyfinity peer.
4. A receiving peer applies the advertisement to `DevicePresenceRegistry` and
   replies once when the sender requested a reply.
5. A device is `ready` only after this two-way presence exchange. A session
   row from `/Sessions` alone is `presenceOnly`: it is visible but must not be
   treated as command-capable.

The `Sessions` WebSocket message can arrive after the initial REST `/Sessions`
response. The transport therefore discovers its ephemeral local session ID from
either source. **It must replace the registry with that WebSocket roster before
announcing presence.** Announcing first creates a zero-target broadcast.

The REST request's `204` means Jellyfin accepted relay delivery; it does not
mean the peer received, decoded, or executed an envelope. Presence replies and
command acknowledgements are the actual delivery proof.

## Scope and cross-install identity

`JellyfinServer.id` is a local database UUID. It differs on Windows, Android,
and every fresh installation. It is correct for local caches and `MediaId`, but
it is invalid as an on-the-wire server identity.

`ConnectedPlaybackScope` deliberately has two server identities:

- `serverId`: this installation's local `JellyfinServer.id`; repositories,
  cache keys, and media resolution use this.
- `wireServerId`: Jellyfin's self-reported stable server ID; envelopes use it.

`ConnectedPlaybackScopeOf` supplies both from the active session. Envelope
decoding compares only `scope.key` (the shared wire server ID plus Jellyfin
user ID), then substitutes the receiving device's local scope into the decoded
envelope. This preserves profile isolation while letting different installs of
the same server communicate.

Never revert this to comparing `ConnectedPlaybackScope` values directly. That
compares local database IDs and reproduces this diagnostic:

```text
Ignored a connected-playback message: message belongs to another server or profile
```

Remote queue entries contain `MediaId`, whose server half is also local. After
the shared envelope scope has been verified, every received `RemoteQueueEntry`
must call `forLocalServer(scope.serverId)`. This rebinding happens in snapshot,
remote-command, and transfer decoding. It is safe because the stable shared
scope was already verified; it is required for artwork, local cache lookups,
and transferred playback to resolve on the receiving device.

## Lifecycle rule

A signed-in idle target remains connected while backgrounded. Opening Remote
on another device must not turn the target into a presence-only row.

The exception is a Fire TV/television whose display is reported asleep. That
target is suspended until the display wakes, then reconnects even if the app is
still backgrounded. Do not reintroduce the old rule that suspended every
backgrounded non-playing target; it makes Spotify-style remote control
impossible.

## Commands, snapshots, and transfer

Commands are sent as a Jellyfinity envelope inside Jellyfin's `SendString`
general command. The sender registers an acknowledgement completer *before*
posting to `/Sessions/<id>/Command`, since a response may arrive before the
REST call returns. The target executes commands serially and responds with an
acknowledgement. Timeout is a real remote delivery failure, not success.

Snapshots are one-way target state projections. They are published only to
peers that advertised `canControl`; a snapshot never grants the receiver
ownership of the target's local queue.

Transfer is a prepare/commit flow. Resolve target-side tracks before pausing
the source. If any entry cannot be resolved, refuse the transfer and leave the
source untouched. Queue data may include server-addressable metadata and item
IDs, but never tokens, authenticated stream URLs, file paths, or download
availability.

SyncPlay is Jellyfin's native group protocol. Join/leave it with
`SyncPlayGroupCubit` and `JellyfinSyncPlayApi`; do not try to synchronize audio
clocks through the general-command envelope.

## Local diagnostics

`ConsoleLogger` writes every `Logger` event to `LocalLogStore`, including debug
events in installed builds. The sidebar route **Logs → Remote** filters
connected-playback, remote, SyncPlay, and `/Sessions` events; **All** retains
the surrounding application context. It holds the latest 10,000 events for the
current process and can copy the visible entries to the clipboard.

Do not log access tokens, full session IDs, stream URLs, or raw payloads. The
existing privacy contract in `Logger.dart` applies to Remote logs too.

Useful signatures, in expected order:

```text
Connected playback: opening Jellyfin socket.
Connected playback: Jellyfin socket connected.
Connected playback: local session discovered; announcing presence.
Connected playback: broadcasting presence to N peer(s).
POST /Sessions/.../Command → 204
Connected playback: received peer presence.
```

Interpretation:

| Observation | Likely boundary to inspect |
| --- | --- |
| No local session discovery | `/Sessions` filtering, socket `Sessions` frames, device identity |
| Presence broadcast to `0 peer(s)` | roster update order or peer filtering |
| Delivery `204`, no peer presence | receiving app WebSocket/lifecycle or incompatible/old peer build |
| `another server or profile` | shared `wireServerId`, not local `serverId` |
| Device visible but not responding | it is `presenceOnly`, not `ready`; trace presence reply first |
| Command timeout | receiver did not acknowledge; inspect target link and command decoding |

## Tests to run

Run these first after a connected-playback change:

```text
flutter test test/infrastructure/jellyfin/connected/jellyfin_session_transport_test.dart
flutter test test/app/connected_playback/connected_playback_link_test.dart
flutter test test/domain/connected_playback/connected_playback_envelope_test.dart
flutter test test/domain/connected_playback/playback_transfer_codec_test.dart
flutter analyze lib/app/connected_playback lib/domain/connected_playback lib/infrastructure/jellyfin/connected
```

The transport suite covers the important discovery race: the initial REST
roster may be empty, then the socket reveals both this local session and a
peer. The test must verify a presence envelope is actually delivered to that
peer. Envelope tests cover separate local server IDs sharing one stable
Jellyfin server ID.

## Change checklist

Before handing off a Remote change:

- Preserve local queue ownership while controlling another device.
- Keep every protocol message profile-scoped with the stable wire server ID
  and Jellyfin user ID.
- Rebind incoming media IDs to the receiver's local server ID only after scope
  verification.
- Treat a `204` relay response as unconfirmed until presence/acknowledgement.
- Keep background targets connected; keep sleeping televisions unavailable.
- Add a behavior test for every race, reconnect, or codec change.
- Rebuild and restart every participating client. Hot reload does not restart
  connection startup or replace an old peer's wire protocol.
