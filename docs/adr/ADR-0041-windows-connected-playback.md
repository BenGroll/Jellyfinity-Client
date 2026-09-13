# ADR-0041: Windows connected playback

## Status

Accepted

## Context

`Roadmap to v0.6.md`'s v0.5.7 asks Jellyfinity to complete Windows as both a
connected player and controller, naming five requirements. ADR-0040 (v0.5.6)
had already deferred one of them explicitly, in its own Consequences: "System
media controls (notification/lock-screen transport, hardware media keys
driving a remote target) remain out of scope, deferred to the v0.5.7-v0.5.9
platform-completion versions."

Scouting this version found that gap was real and concrete:
`JellyfinityApp`'s `CallbackShortcuts` wired every hardware media key
(`mediaPlayPause`, `mediaPlay`, `mediaPause`, `mediaTrackNext`,
`mediaTrackPrevious`, `mediaFastForward`, `mediaRewind`) straight to local
`PlaybackCubit`, unconditionally — even while this device was
remote-controlling another one via `PlaybackControlCubit` (v0.5.6). A media
key press would silently act on a dormant local queue no screen was even
showing, instead of the device actually being controlled.

Windows' System Media Transport Controls integration itself needed no new
native code: `audio_service` + the existing `audio_service_win` plugin
(`third_party/audio_service_win`, ADR-0013/ADR-0029) already surface a
lock-screen/media-panel session backed by `JustAudioPlaybackEngine`, which
*is* the `audio_service.BaseAudioHandler` as well as the domain
`PlaybackEngine`. What that class lacked was the same "which player is
active" branch `JellyfinityApp` lacked — its `play`/`pause`/`seek`/
`skipToNext`/`skipToPrevious` always drove `_player` (the local `just_audio`
deck) regardless of `PlaybackControlCubit.isControlling`.

## Decision: `ActiveTransportRoute`, a domain seam infrastructure can ask without depending on the app layer

`JustAudioPlaybackEngine` sits in `lib/infrastructure/playback/`; the app
layer's `PlaybackControlCubit` sits in `lib/app/connected_playback/`. The
architecture invariant (`UI -> presentation -> domain contracts <-
infrastructure`) forbids the engine depending on the cubit directly. A new
domain interface, `ActiveTransportRoute`
(`lib/domain/connected_playback/ActiveTransportRoute.dart`), gives the engine
exactly the question it needs — `isRemote`, and `play`/`pause`/`next`/
`previous`/`seek` to send when it is — without knowing `PlaybackControlCubit`
exists.

`ActivePlaybackRouteAdapter` (`lib/app/connected_playback/`) implements it by
delegating to `getIt<PlaybackControlCubit>()`, guarding each send with
`state.commandAvailable(kind)` exactly the way `MiniPlayer`'s on-screen
buttons already do — an unsupported command is dropped silently, the same as
a disabled button, rather than falling through to local playback. `bootstrap()`
constructs one and hands it to `JustAudioPlaybackEngine` as an optional named
constructor parameter (`null` everywhere untouched — every existing test and
platform that never passes one keeps the pre-v0.5.7 "always local" behavior
by construction).

`play`, `pause` and `seek` are shared between the domain `PlaybackEngine`
contract (`PlaybackCubit` calls these for legitimate local playback) and the
`BaseAudioHandler` contract (the OS calls these directly for a lock-screen or
system media-panel press) — the same methods serve both roles by design (see
`JustAudioPlaybackEngine`'s own class doc). Routing them to
`ActiveTransportRoute` when `isRemote` is safe only because, since v0.5.6,
every screen already checks `PlaybackControlCubit.isControlling` before ever
calling `PlaybackCubit` (`MiniPlayer`'s doc: "never the other way around") —
so a local `PlaybackCubit` call while remote-controlling should not happen in
the first place, and this ADR does not change that invariant, only extends it
to the one entry point that bypasses every cubit: an OS or hardware button
press. `skipToNext`/`skipToPrevious` are `BaseAudioHandler`-only overrides
(the domain contract uses `skipToIndex`, which `PlaybackCubit` calls
instead), so they needed no such reasoning — they are unambiguously
system-control entry points already.

`JellyfinityApp`'s `CallbackShortcuts` bindings were changed to check the same
`PlaybackControlCubit.isControlling`/`commandAvailable` pair directly
(`_mediaTogglePlayPause`, `_mediaPlay`, `_mediaPause`, `_mediaNext`,
`_mediaPrevious`, `_mediaSeekBy`) before falling back to local `PlaybackCubit`
— the in-app, foreground half of the same fix, reusing the exact
`getIt<PlaybackControlCubit>()` resolution `MiniPlayer`/`NowPlayingPage`/
`QueuePage` already use.

## What this version does not settle

Four of the roadmap's five bullets need real Windows (and, for the
cross-device bullet, Android) hardware to validate and were out of reach in
this environment:

- Session presence/command delivery through minimize/sleep/wake/network
  changes/reconnect relies on Flutter's cross-platform `AppLifecycleState`
  (`ConnectedPlaybackLink`, v0.5.2) today; Windows sleep/wake is not always
  observable through it and may need a native `WM_POWERBROADCAST` signal —
  unverified without a Windows machine to sleep and wake.
- Device-picker/remote Now Playing polish for narrow/wide windows, pointer
  hover, keyboard-only use, high DPI scaling and multiple displays needs
  visual iteration on a real Windows desktop, not a headless test run.
- Cross-validating Windows as source/destination/controller against Windows
  peers, then against Android test clients, needs the actual devices the
  roadmap names.
- The manual acceptance pass and any native lifecycle smoke test additions
  need the same hardware.

`docs/windows.md`'s device-acceptance checklist gained the remote-control
scenarios this version's code change makes possible to check (media keys and
the system media panel while controlling another device; media keys with
nothing controlled) so the next person at a Windows machine has a concrete
list.

## Tests

`test/app/connected_playback/active_playback_route_adapter_test.dart` drives
`ActivePlaybackRouteAdapter` against a real `PlaybackControlCubit` controlling
a real (fake-transport) target — the same harness
`playback_control_cubit_test.dart` trusts — proving `isRemote` tracks
`isControlling`, that `play`/`pause`/`next`/`seek` reach the real target, that
an unadvertised command is dropped, and that local playback is never touched.
`test/app/media_key_routing_test.dart` pumps the real `JellyfinityApp` widget
tree and sends actual `LogicalKeyboardKey` media-key events, proving they
reach `PlaybackControlCubit` instead of local `PlaybackCubit` while controlling,
and still drive local playback when nothing is controlled.

## Consequences

- No native Windows code changed; SMTC integration continues to ride on the
  existing `audio_service_win` plugin.
- `ActiveTransportRoute` is a small, one-purpose seam — it is not a general
  replacement for `PlaybackControlCubit` and nothing outside
  `JustAudioPlaybackEngine`/`ActivePlaybackRouteAdapter` should implement or
  consume it.
- The four hardware-dependent bullets above remain open and are not claimed
  as done; they need a Windows (and Android) device pass before v0.5.7 can be
  called complete against the roadmap's own "done when."
