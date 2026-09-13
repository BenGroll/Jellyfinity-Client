# ADR-0043: Android TV and Fire TV connected playback

## Status

Accepted

## Context

`Roadmap to v0.6.md`'s v0.5.9 asks the television to become both an
effortless playback destination and a fully capable 10-foot controller,
naming five requirements. Scouting this version against what ADR-0036 and
the Windows/Android connected-playback ADRs (0041, 0042) already shipped
narrowed which of the five were still open:

- Television mode itself, D-pad focus traversal, larger typography and
  spacing, and hardware/system media-key routing to whichever player is
  active are already platform-neutral (ADR-0036, ADR-0041, ADR-0042).
  `AppTheme`'s `television` flag scales `AppTypography` and `AppSpacing`
  globally through `context.tokens`, so any screen already built on the
  design system — including ones added after ADR-0036, like the device
  picker (ADR-0039) and remote Now Playing (ADR-0040) — inherits "large
  readable labels" and overscan-safe spacing for free, with no
  television-specific code of its own.
- `ConnectedPlaybackLink`'s background/playing reconciliation (ADR-0042) is
  itself platform-neutral: it reads `AppLifecycleState`, not an
  Android-versus-television distinction, so a television target already
  stays reachable while playing in the background the same way a phone
  does. But that reconciliation cannot see a television going to sleep at
  all: unlike backgrounding a phone, a television's display turning off
  does not reliably change `AppLifecycleState` — the `Activity` can stay
  `resumed` with the screen simply dark — so an asleep television would
  keep advertising itself as `ready` indefinitely. The roadmap's "an
  asleep or stopped TV expires promptly as a target" names exactly this
  gap, and needs a native signal `AppLifecycleState` cannot supply; see
  "Decision" below for what was added and "What this version does not
  settle" for what a full HDMI-CEC/standby signal would still require.
- What was concretely wrong, found by reading rather than by device:
  ADR-0036 gave only screens reached by in-app navigation — the shell's
  destinations — "explicit initial focus," on the reasoning that reading
  order handles everything else. The device picker (`DevicePickerSheet`,
  ADR-0039) is a modal overlay, not a navigated screen, and never received
  that treatment: it opened with no row focused, leaving a D-pad user to
  discover by trial which arrow press finds the list at all. The roadmap's
  "device selection and remote ownership state in predictable D-pad order
  ... with explicit initial/restored focus" names exactly this screen.

## Decision: the device picker autofocuses the row that already names remote ownership

`_DeviceList` (`DevicePickerSheet.dart`) now computes a `primarySessionId` —
the device currently being controlled if one exists, otherwise this
device's own row — and passes `autofocus: true` down to the matching
`_DeviceRow`'s `ListTile` only in television mode, read from the existing
`TelevisionModeScope`. Picking the ownership row rather than always the
first list item keeps "predictable" meaning what a listener would expect:
the row that already tells them who has playback is the one they are most
likely to act on next, matching why `_RowStatus` singles out "Controlling —
tap to stop" and "Playing here" among every other row's more passive
wording.

Off television the flag stays `false` everywhere, so touch/pointer
picking is unaffected; `ListTile.autofocus`/`focusNode` already exist on the
widget, so no new focus-management plumbing was needed.

## Decision: an asleep television expires as a target regardless of `AppLifecycleState`

`MainActivity` registers a runtime `BroadcastReceiver` for Android's
`ACTION_SCREEN_ON`/`ACTION_SCREEN_OFF` — protected broadcasts that cannot be
declared in the manifest — only while Dart is actually listening, and
forwards it through a new `io.nachbar.jellyfinity/device/display`
`EventChannel`. `TelevisionDisplayMonitor` (`lib/app/platform`) wraps that
channel the same way `TelevisionModeDetector` wraps its own: a missing or
failing host just never emits, rather than the caller having to guess.

`ConnectedPlaybackLink` subscribes to it only once `TelevisionModeDetector`
has confirmed a television host — a phone or desktop's own backgrounding is
already what `didChangeAppLifecycleState` reconciles against, and a display
event on either would be meaningless. A new `_televisionAsleep` flag is
checked first in `_reconcileBackgroundConnection`, ahead of the existing
`_backgrounded`/playing check: falling asleep suspends the transport
unconditionally, even if something is still playing, because unlike a
phone's background-audio case (ADR-0042) there is no scenario where a dark,
asleep television is still a destination worth advertising. Waking clears
the flag and defers to whichever rule already applies — the background
reconcile if still backgrounded, a direct `resume()` if not — rather than
calling both, which would race `resume`'s asynchronous reconnect against a
reconcile that might decide to suspend again.

## Tests

- `test/features/playback/device_picker_widget_test.dart` gained two
  cases: opening the picker in television mode focuses the "This device"
  row when nothing is being controlled, and the same picker off television
  leaves every row unfocused. The existing "renders without overflow at
  television scale" case is unchanged and still covers layout at
  1920x1080.
- `test/app/connected_playback/connected_playback_link_test.dart` gained a
  `FakeTelevisionPlatform`-backed group covering an asleep television
  expiring even while playing and restoring on wake, and an asleep,
  already-backgrounded, non-playing television staying expired once it
  wakes rather than reconnecting unconditionally.
- `test/app/fire_tv_platform_test.dart` gained a case pinning the new
  `EventChannel` name and that the receiver is registered/unregistered at
  runtime rather than declared in the manifest.

## What this version does not settle

Three of the roadmap's five bullets, plus a real-hardware limitation on
the one just addressed, still need physical Android TV and Fire TV
hardware — and, for the cross-device bullet, Windows and Android phones —
to design or validate at all:

- Screen-on/off is a reasonable proxy for "asleep or stopped," not the
  whole of it: a television turned off at the wall, an HDMI input switch
  away from Jellyfinity, or a genuine standby broadcast some vendors send
  instead of (or in addition to) `ACTION_SCREEN_OFF` are not covered, and
  whether Fire OS delivers these standard Android broadcasts identically
  across devices is unverified without hardware.
- Confirming remote play/pause/previous/next/seek/Menu/Back/volume each
  reach the active player exactly once — not zero, not twice via both
  `audio_service`'s MediaSession callback and Flutter's `CallbackShortcuts`
  — needs a physical remote's actual key events, which the existing
  `JellyfinityApp.dart`/`app_shell.dart` bindings cannot be verified
  against headlessly.
- Cross-validating television as source, destination, and controller
  against Windows and Android, including name collisions and a phone
  controlling with the TV screen off, needs the actual devices the
  roadmap names.
- Physical-device acceptance for launcher entry, D-pad, media keys,
  overscan, background playback, sleep/wake, and reconnect without Google
  Play Services needs the same hardware, echoing the position ADR-0041 and
  ADR-0042 were each left in for their own platforms.

## Consequences

- One native addition: `MainActivity` registers/unregisters a
  `BroadcastReceiver` around the lifetime of the new `EventChannel`'s
  listener. No new dependency, and no wire or schema change — the display
  signal only ever calls `suspend()`/`resume()` on the existing transport.
- `DevicePickerSheet.dart` gained a `TelevisionModeScope` read it did not
  need before; every other screen's television behavior is unchanged.
- `ConnectedPlaybackLink` now depends on two more platform-detection
  entry points (`TelevisionModeDetector`, `TelevisionDisplayMonitor`),
  both already following the same "missing host means no-op" contract
  the class already relied on for `TelevisionModeDetector.detect()`.
- The three hardware-dependent bullets, plus the screen-on/off
  approximation's own limits, remain open and are not claimed as done;
  they need an Android TV/Fire TV device pass, and the cross-device
  bullet a multi-device pass, before v0.5.9 can be called complete
  against the roadmap's own "done when."
