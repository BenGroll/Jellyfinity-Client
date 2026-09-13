# Jellyfinity v0.5.1-v0.6.0 specifications

Read only the assigned version. This arc deliberately builds the connected
playback foundation before exposing controls, then completes each supported
platform in turn. Every version requires focused changes, behavior tests, a
current changelog entry, and passing CI. Record durable transport, ownership,
and persistence decisions in an ADR.

## Big goal - Connected listening

Make a Jellyfinity session follow the listener between their devices. A user
can see their compatible Jellyfinity devices, choose where sound plays,
transfer the complete playable queue without restarting the listening context,
and control the active player from another device.

The experience should feel as dependable as Spotify Connect while remaining
self-hosted. Jellyfinity uses the authenticated Jellyfin server's session API,
remote-control endpoints, and WebSocket delivery as the relay. It does not add
a Jellyfinity account, proprietary cloud service, local-network discovery
protocol, or direct device-to-device socket.

"Transfer playback" has a strict meaning in this roadmap. The destination
receives the ordered queue, current item, position, shuffle and repeat state,
and becomes the only playback owner after it confirms that it is ready. Merely
opening the current song on another device is not a completed transfer.

## Connected playback invariants

- Connected playback is scoped to one saved server and one authenticated
  profile. Never discover, command, or transfer state across profiles or
  servers, even when Jellyfin grants broader remote-control permissions.
- Only a device producing audio owns the authoritative live queue. A controller
  holds a revisioned projection and must not merge it into its unrelated local
  persisted queue.
- Every compatible device advertises a protocol version and explicit
  capabilities. The UI offers only commands the target currently accepts and
  explains unavailable, stale, permission-denied, offline, and incompatible
  states.
- Commands carry a unique id, target session, expected state revision, and a
  bounded lifetime. Targets process duplicates once, serialize competing
  controllers, acknowledge the resulting revision, and reject stale structural
  mutations so controllers can resynchronize.
- A handoff is prepare, commit, and acknowledge. The source keeps enough state
  to resume if the target cannot resolve the queue, start playback, or confirm
  ownership. Two devices must never continue playing because an acknowledgement
  was lost.
- Transfer only server-addressable music metadata and identifiers. Never send
  credentials, authenticated stream URLs, download paths, or audio between
  clients. The target independently chooses its local download or server stream
  and applies its own quality, normalization, and crossfade settings.
- Refuse a transfer before stopping the source when the target cannot reproduce
  the queue faithfully. Local-only items, unsupported media, an unreachable
  server, an oversized payload, or missing playback permission must have a
  specific explanation; entries are never silently removed or reordered.
- WebSocket reconnect always performs a full session/state reconciliation
  before accepting more structural commands. Bounded polling may recover
  presence, but a device without working command delivery is not presented as
  a ready handoff target.
- Offline playback remains device-local. It can continue uninterrupted, but
  device discovery, remote control, and handoff clearly become unavailable
  until the matching Jellyfin session is reachable again.
- Existing local playback, persistent queues, background audio, system media
  controls, progress reporting, and account switching remain valid when no
  second device exists.

## Platform acceptance for this arc

The foundation and UI use shared domain and presentation contracts. Windows,
Android, and television mode are then completed as explicit product increments:

- Windows supports both player and controller roles with pointer, keyboard,
  windowed layouts, sleep/wake recovery, and Windows media-session controls.
- Android supports both roles across foreground and background operation,
  notifications, media buttons, audio focus, connectivity changes, and process
  recreation.
- Android TV and Fire TV share ADR-0036's television capability path. Device
  selection and remote playback are 10-foot, D-pad-first experiences that do
  not require Google Play Services.

Each platform release validates transfers in both directions with every
platform already completed in the arc. Existing iOS local playback must not
regress, but adding iOS as a connected player/controller is outside v0.6.0.

## v0.5.1 - Connected playback contract

**Goal:** Establish one testable vocabulary and ownership model for connected
playback before network or UI code depends on it.

**Required:**

- Record an ADR for the target-authoritative model and Jellyfin-mediated
  transport. Define domain models for a connected device, advertised
  capabilities, remote playback snapshot, command, acknowledgement, transfer,
  and connection/ownership state without exposing Jellyfin DTOs.
- Put transport, discovery, command delivery, and handoff behind replaceable
  domain contracts. Keep `PlaybackQueue` and `PlaybackEngine` application-owned
  as required by ADR-0013; a remote target is not another audio engine.
- Specify a versioned wire envelope and compatibility rules. Unknown protocol
  versions or commands are ignored safely and surfaced as incompatible rather
  than crashing either client.
- Define monotonic state revisions, command idempotency, timeout behavior,
  payload/queue bounds, clock-independent expiry, and normalized failures.
- Build deterministic fakes and contract tests for two clients, duplicate and
  reordered messages, stale revisions, timeouts, account isolation, and
  capability negotiation.

**Done when:** The complete discovery, control, synchronization, and handoff
conversation can be exercised in pure tests without a Flutter widget, audio
backend, or live Jellyfin server.

## v0.5.2 - Device presence and capability transport

**Goal:** Let compatible Jellyfinity instances find one another reliably
through their shared Jellyfin server.

**Required:**

- Add a single lifecycle-aware Jellyfin session transport that posts this
  client's full playback capabilities, consumes server WebSocket messages, and
  uses the authenticated session endpoints for discovery and commands.
- Bind the stable Jellyfinity device identity to the current ephemeral server
  session without treating the session id, saved account, user, or device as
  interchangeable. Give duplicate friendly names a stable distinguishing hint.
- Maintain a profile- and server-scoped presence read model with last-seen,
  reachability, protocol version, player/controller capabilities, and local or
  remote activity. Expire stale sessions and clear them immediately on logout,
  account switch, or server removal.
- Reconnect with bounded backoff and perform a full REST/session resync after a
  socket interruption. Normalize unsupported-server, proxy/WebSocket,
  authentication, permission, and network failures independently.
- Test multi-device discovery, duplicate device names, stale expiry, reconnect,
  reverse-proxy socket failure, lifecycle transitions, and isolation between
  saved accounts. Add an integration test against the minimum Jellyfin server.

**Done when:** Two signed-in Jellyfinity instances on the same server and
profile discover accurate capabilities and liveness, and neither can see or
retain another profile's devices.

## v0.5.3 - Remote state and command execution

**Goal:** Make one Jellyfinity device a dependable remote control for another
without changing which device owns playback.

**Required:**

- Publish bounded, revisioned snapshots of the active target's queue, current
  item, position, playing/buffering state, shuffle, repeat, supported commands,
  and target volume when the platform can expose it honestly.
- Receive and execute play, pause, previous, next, seek, play-queue-entry,
  shuffle, repeat, and supported volume commands through the existing
  `PlaybackCubit` and queue contracts. Do not create a second control path into
  the audio engine.
- Acknowledge each applied command with the resulting state revision. Retry
  transient delivery safely, deduplicate commands across reconnect, and make
  target state win over controller optimism or clock drift.
- Serialize simultaneous controllers at the target. Reject stale queue
  mutations with a resync response while allowing safe transport commands to be
  applied against current state.
- Keep Jellyfin playback-progress reporting owned by the target. A controller
  never reports a second play session for music it is not producing.
- Test every capability and rejection path, multi-controller races, high-rate
  position updates, reconnect resync, command expiry, target shutdown, and a
  large but bounded queue.

**Done when:** Headless application tests can control a playing client from a
second client and converge on the target's state through loss, duplication,
reordering, and reconnect.

## v0.5.4 - Atomic playback handoff

**Goal:** Transfer a listening session between compatible devices without a
surprising restart, queue change, or double playback.

**Required:**

- Preflight the destination's protocol, playback capability, media access, and
  ability to reproduce the entire bounded queue before changing the source.
- Transfer ordered entries, queue origin/context, current item and position,
  shuffle order/seed where needed, repeat mode, and whether playback should be
  playing or paused. Preserve duplicate entries and true queue order.
- Implement prepare/ready/commit/acknowledge with a transfer id and explicit
  ownership states. Pause the source only after the target is ready; retire the
  source only after the target confirms playback ownership.
- Recover deterministically from target rejection, source or target disconnect,
  server restart, delayed acknowledgement, duplicate commit, and cancellation.
  Resume the source when safe or leave both paused with a clear recoverable
  state; never guess that a transfer succeeded.
- Resolve every item afresh on the target so its own download can replace a
  stream and its own stream-quality settings apply. Reject local-only or
  otherwise unresolvable queues before handoff.
- Test position tolerance, paused transfers, duplicates, shuffle/repeat, mixed
  downloaded/streamed sources, unavailable items, all protocol phases, and
  exactly-one-owner invariants.

**Done when:** Automated two-client scenarios transfer the full playable
listening context at the current position and prove that one, and only one,
device owns playback after success or recovery.

## v0.5.5 - Device picker and ownership UI

**Goal:** Make playback location visible and make choosing another device a
clear, low-friction action.

**Required:**

- Add a device action to the mini-player and Now Playing surfaces using the
  established responsive design system. Its state names the active device; it
  must not imply that this device is playing when it is only controlling.
- Present "This device" and compatible remote devices with active, available,
  connecting, unavailable, stale, incompatible, and permission-denied states.
  Show capabilities and concise reasons only where they affect an action.
- Let the user transfer playback or bring it back to this device. Keep the
  picker open through prepare/commit progress, prevent duplicate transfer
  requests, and show success, rollback, or an actionable failure.
- Handle no other devices, duplicate names, devices disappearing while open,
  offline/work-offline mode, account switching, and a remote session ending.
- Add semantics, focus order, keyboard activation, and widget/golden coverage
  for compact phone, windowed desktop, and television-scale constraints. This
  version exposes the shared UI but does not claim platform completion.

**Done when:** A listener can always tell where audio is playing and can choose
a compatible destination without losing the current session or interpreting a
silent spinner.

## v0.5.6 - Remote Now Playing and queue controls

**Goal:** Let any connected Jellyfinity device operate the active player with
the same confidence as local Now Playing.

**Required:**

- Bind the mini-player, Now Playing, and queue to either local playback state or
  the selected remote projection through one presentation contract. Never
  overwrite the controller's dormant local queue with the remote queue.
- Support every capability completed in v0.5.3: transport, seek, current-item
  selection, shuffle, repeat, queue edits, and volume where advertised. Disable
  or omit unsupported controls consistently.
- Distinguish command pending, applied, rejected, timed out, reconnecting, and
  target-ended states. Acknowledged target state corrects optimistic motion,
  especially seek position, queue edits, and volume.
- Keep artwork, favorite/download state, lyrics, and navigation local to the
  controller's matching profile while playback and queue state come from the
  target. Partial metadata failure must not disable transport controls.
- Provide a direct route back to device selection and a deliberate action to
  stop controlling without stopping the player. System media controls remain a
  platform-rollout concern in v0.5.7-v0.5.9.
- Test local/remote switching, every pending/failure state, structural command
  conflicts, partial metadata, short windows, large queues, and accessible
  focus/semantics.

**Done when:** A user can control and inspect the active remote queue throughout
Jellyfinity, and the UI remains explicit about whether state is local, remote,
pending, stale, or unavailable.

## v0.5.7 - Windows connected playback

**Goal:** Complete Windows as both a connected player and controller.

**Required:**

- Keep session presence and command delivery correct across window minimize,
  restore, sleep/wake, network changes, server reconnect, and clean app exit.
  A closed process is unavailable, not a phantom target.
- Route keyboard shortcuts and Windows media-session controls to the selected
  active player while keeping labels/artwork honest about a remote target.
  Avoid duplicate local and remote command dispatch.
- Polish device selection and remote Now Playing for narrow and wide windows,
  pointer hover, keyboard-only use, high scaling, and multiple displays.
- Validate Windows as source, destination, and third-device controller against
  completed Windows peers; then validate handoff/control in both directions
  with Android test clients used by the shared integration harness.
- Add Windows lifecycle/platform tests and manual acceptance for background
  playback, system controls, sleep/wake, network loss, and audio-device change.

**Done when:** A Windows device can reliably own, transfer, and remotely control
playback using pointer, keyboard, and system media controls through normal
desktop lifecycle changes.

## v0.5.8 - Android connected playback

**Goal:** Complete Android phone and tablet as both connected players and
controllers.

**Required:**

- Keep a playing target reachable through Android foreground-service and
  background-audio rules. Reconcile honestly after process recreation, Doze,
  connectivity changes, and the OS stopping a controller-only process.
- Route notification, lock-screen, headset, Bluetooth, and hardware media
  controls exactly once to the selected active player. Preserve audio focus,
  becoming-noisy, call interruption, and local handoff behavior on the target.
- Make device selection and remote Now Playing work across touch sizes,
  rotation, system text scaling, gesture/back navigation, and offline mode.
- Validate Android as source, destination, and third-device controller in both
  directions with Windows, including local-download resolution on Android and
  remote streams outside the home network.
- Add lifecycle/platform tests and physical-device acceptance for background
  playback, notification controls, Bluetooth controls, Doze recovery, process
  recreation, and Wi-Fi/mobile transitions.

**Done when:** Android can own or control a connected session through realistic
mobile lifecycle and media-control events without duplicate playback, lost
ownership, or a misleading notification.

## v0.5.9 - Android TV and Fire TV connected playback

**Goal:** Make the television the effortless listening destination and a fully
capable 10-foot controller.

**Required:**

- Extend ADR-0036's shared television mode; do not fork a separate Leanback or
  Fire TV UI. Put device selection and remote ownership state in predictable
  D-pad order with overscan-safe layout, large readable labels, and explicit
  initial/restored focus.
- Route remote play/pause, previous/next, seek, Menu, Back, and supported volume
  keys exactly once to the selected active player. Preserve platform handling
  for keys Jellyfinity cannot or must not consume.
- Keep a television target reachable during background audio and reconcile
  after sleep, HDMI/display state changes, network loss, app restart, and the OS
  reclaiming the process. An asleep or stopped TV expires promptly as a target.
- Validate TV as source, destination, and controller in both directions with
  Windows and Android. Device-name collisions and a phone acting as controller
  while the TV screen is off must remain understandable.
- Add widget/native tests for focus, key routing, launcher capability, and
  lifecycle state. Complete physical acceptance on Android TV and Fire TV for
  launcher entry, D-pad, media keys, overscan, background playback, sleep/wake,
  and reconnect without Google Play Services.

**Done when:** A listener can send music to a television and control it from the
TV, phone, or Windows device with a polished remote-first experience on both
Android TV and Fire TV.

## v0.6.0 - True cross-device playback

**Goal:** Harden the completed foundation, UI, and platform implementations into
one trustworthy connected-listening release.

**Required:**

- Run an end-to-end role matrix covering Windows, Android, and Android TV/Fire
  TV as source, destination, and controller, including every handoff direction
  and a third controller joining an active session.
- Verify server/profile isolation, remote-control permissions, incompatible
  protocol versions, duplicate device identity/name, unsupported targets,
  large bounded queues, local-only items, and server versions beginning at the
  documented minimum.
- Exercise command loss/duplication/reordering, slow networks, reverse proxies,
  WebSocket reconnect, server restart, source/target crash, app upgrade, account
  switch, offline transition, and a transfer interrupted at every protocol
  phase. Instrument only local diagnostic logs and redact identifiers/tokens.
- Tune snapshot frequency, position interpolation, reconnect backoff, command
  latency, memory, and battery/network use without weakening authoritative
  reconciliation. Connected playback must remain bounded for normal 130k-song
  libraries and long-lived TV sessions.
- Complete accessibility, localization-ready copy, privacy/security review,
  migrations and rollback behavior, release notes, support documentation, CI,
  Android build, Windows build, and the physical acceptance left by each
  platform milestone.
- Preserve a graceful local-only experience when there is one device, no remote
  permission, no WebSocket path, or no network. Connected playback is an
  enhancement, never a new dependency for pressing Play.

**Done when:** A listener can begin music on any completed platform, move the
full live session to any other, and control it from a third through failures and
reconnects, while exactly one device owns playback and local listening remains
fully dependable.

## Non-goals for v0.5.1-v0.6.0

Synchronized multi-room/group playback, speaker grouping, casting protocols,
Bluetooth pairing, controlling non-Jellyfinity clients, accepting control from
another Jellyfin user, cross-server transfer, transferring local-only audio,
video playback, collaborative queues, a Jellyfinity cloud account/relay, and
iOS connected-player/controller completion are outside this arc.
