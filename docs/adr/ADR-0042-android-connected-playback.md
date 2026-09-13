# ADR-0042: Android connected playback

## Status

Accepted

## Context

`Roadmap to v0.6.md`'s v0.5.8 asks Jellyfinity to complete Android phone and
tablet as both connected players and controllers, naming five requirements.
Scouting this version against v0.5.7's own findings (ADR-0041) narrowed which
of the five were still open:

- Hardware/notification/lock-screen/headset/Bluetooth media-key routing to
  the active player is not Android-specific — `ActiveTransportRoute` and
  `ActivePlaybackRouteAdapter` (ADR-0041) sit in `JustAudioPlaybackEngine`,
  the same `audio_service.BaseAudioHandler` Android's foreground service
  (ADR-0013) already drives via `AudioService`/`MediaButtonReceiver` in
  `AndroidManifest.xml`. Nothing there assumes a platform, so a Bluetooth or
  headset button reaching this device's engine already gets the v0.5.7
  routing for free.
- Device selection and remote Now Playing are the same platform-neutral
  screens Windows already exercises; Android's touch/rotation/text-scaling
  concerns are visual iteration on those screens, not new architecture.
- What was concretely wrong, found by reading rather than by device: the one
  Android-specific requirement — "keep a playing target reachable through
  Android foreground-service and background-audio rules" — was not met.
  `ConnectedPlaybackLink.didChangeAppLifecycleState` suspended the
  connected-playback transport on every `paused`/`detached` transition
  unconditionally, but `JellyfinSessionTransport.suspend`'s own doc names
  what it is actually for: "What the app calls when it is no longer in the
  foreground **and no longer playing**." The call site never checked the
  second half. On Android specifically this mattered: `audio_service`'s
  foreground service exists precisely to keep the process — and therefore
  this device as a reachable connected-playback target — alive while
  backgrounded and playing, but the socket was being dropped anyway, making
  a playing Android device invisible to another device's picker for as long
  as it kept playing in the background.

## Decision: `ConnectedPlaybackLink` tracks background state and playing state independently, and reconciles on either changing

`ConnectedPlaybackLink` gained a `PlaybackCubit` dependency — the same
composition-root precedent `ConnectedPlaybackTargetLink` already set for
reading local playback state from the app layer — and a `_backgrounded` flag
mirroring `AppLifecycleState` (not `_transport`'s own suspended flag, since
the two can now disagree by design: backgrounded-and-playing is a state the
transport must stay connected through).

A new `_reconcileBackgroundConnection` is the single place that decides:
suspend when backgrounded and not playing, resume when backgrounded and
playing, do nothing in the foreground (the existing unconditional
`_transport.resume()` on `AppLifecycleState.resumed` is untouched — it is a
no-op when playback already kept the socket alive, since `resume()` only
acts on a suspended or missing socket). It is called from two places:

- Every `paused`/`detached` transition, replacing the old unconditional
  `_transport.suspend()`.
- Every `PlaybackCubit` state change, via a new subscription started
  alongside the existing `SessionCubit` one, but only while `_backgrounded`
  is already true — playback starting, pausing, or finishing can each
  happen independently of any lifecycle transition, and either direction
  (a backgrounded device starts playing; a backgrounded, playing device
  stops) needs to flip the connection the same way a lifecycle transition
  would.

## What this version does not settle

Four of the roadmap's five bullets need real Android hardware (and, for the
cross-device bullet, Windows) to validate, the same position v0.5.7 was left
in for Windows:

- Doze, connectivity changes, and the OS reclaiming a controller-only
  process (one with no foreground service holding it alive) are not
  exercised by this change directly. A controller-only device already goes
  through the same "backgrounded and not playing" path `suspend()` covers,
  so losing that process is expected and reconciles honestly on relaunch —
  `PlaybackControlCubit`'s `device` starts `null` in a fresh process, so no
  stale "controlling" state can survive a kill — but Doze's actual timing
  and a genuine process recreation mid-session are unverified without a
  physical device.
- Device-picker/remote Now Playing polish for touch sizes, rotation, system
  text scaling, and gesture/back navigation needs visual iteration on a real
  Android device, not a headless test run.
- Cross-validating Android as source/destination/controller against Windows
  peers needs the actual devices the roadmap names.
- Physical-device acceptance for background playback, notification controls,
  Bluetooth controls, Doze recovery, process recreation, and Wi-Fi/mobile
  transitions needs the same hardware.

## Tests

`test/app/connected_playback/connected_playback_link_test.dart` gained three
cases against the existing `FakeJellyfinSocket`/`FakePlaybackEngine` harness:
a backgrounded device that is playing keeps its socket open; playback ending
while already backgrounded releases it; and playback starting while already
backgrounded restores it. The existing "leaving the foreground releases the
socket" case is unchanged and still covers the not-playing background path.

## Consequences

- No native Android code changed; the foreground service and media-button
  wiring continue to ride on the existing `audio_service` integration
  (ADR-0013).
- `ConnectedPlaybackLink` now depends on `PlaybackCubit`, matching the
  precedent `ConnectedPlaybackTargetLink` already set for the app layer
  reading local playback state; neither the session-driven nor the
  lifecycle-driven half of its existing behavior changed.
- The four hardware-dependent bullets above remain open and are not claimed
  as done; they need an Android (and Windows) device pass before v0.5.8 can
  be called complete against the roadmap's own "done when."
