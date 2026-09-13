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
  does. What the roadmap actually asks beyond that — expiring an *asleep or
  stopped* television promptly, and reconciling HDMI/display and network
  transitions specifically — needs native signals no Dart lifecycle event
  currently reports, and is not addressed here; see "What this version does
  not settle."
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

## Tests

`test/features/playback/device_picker_widget_test.dart` gained two cases:
opening the picker in television mode focuses the "This device" row when
nothing is being controlled, and the same picker off television leaves
every row unfocused. The existing "renders without overflow at television
scale" case is unchanged and still covers layout at 1920x1080.

## What this version does not settle

Four of the roadmap's five bullets need real Android TV and Fire TV
hardware — and, for the cross-device bullet, Windows and Android phones —
to design or validate at all:

- Distinguishing "backgrounded and playing" (keep reachable, ADR-0042's
  existing behavior) from "asleep or stopped" (expire promptly) needs a
  native signal — display/HDMI state or an Amazon/Android TV standby
  broadcast — that neither `AppLifecycleState` nor anything already in
  `MainActivity.kt` reports today. No such signal was added here.
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

- No native Android/Fire OS code changed, no new dependency, and no wire
  or schema change.
- `DevicePickerSheet.dart` gained a `TelevisionModeScope` read it did not
  need before; every other screen's television behavior is unchanged.
- The four hardware-dependent bullets above remain open and are not
  claimed as done; they need an Android TV/Fire TV device pass, and the
  cross-device bullet a multi-device pass, before v0.5.9 can be called
  complete against the roadmap's own "done when."
