# ADR-0036: Fire TV platform support

## Status

Accepted

## Context

Jellyfinity's Android package runs on Fire OS, but it was not discoverable from
a television launcher and its authenticated shell assumed touch: primary
destinations lived in a bottom bar, focus competed with nested navigators, and
the compact type/card scale was intended for a handheld display. Screen width
alone cannot identify a TV because Android tablets and Windows desktop windows
can be equally wide.

Fire TV supplies four-way D-pad, center/select, Back and media keys. The same
application must retain Android phone/tablet, iOS and Windows behavior, and it
must not depend on Google Play Services, which Fire OS does not provide.

## Decision

- Keep one Android application and one Flutter presentation tree. The manifest
  advertises an optional Leanback feature, a Leanback launcher category, a
  320x180 xhdpi banner, and makes touchscreen/fake-touch optional. Ordinary
  Android launcher eligibility remains.
- Let MainActivity report television capability through a small method
  channel. It checks Android's UI_MODE_TYPE_TELEVISION and Amazon's
  amazon.hardware.fire_tv feature. Dart treats a missing/failing host method
  as non-TV; it never guesses from pixels.
- Carry that result in TelevisionModeScope. TV mode selects larger typography,
  spacing, focus contrast and targets, plus overscan-safe page insets. Home
  shelves use larger artwork. Existing width-responsive views such as Now
  Playing continue choosing their wide layout normally.
- Replace the bottom navigation bar with a persistent left rail only in TV
  mode. The active destination explicitly receives initial focus after nested
  navigation settles. Reading-order traversal, Material focus feedback and
  Flutter's scroll-to-focus behavior provide predictable D-pad movement.
- Map center/select and controller A to Flutter's focused ActivateIntent.
  Menu opens the existing app sidebar. Back first closes inline search or pops
  navigation; the Android system owns the final return to the Fire TV home
  screen. Play/pause, next/previous and ten-second rewind/fast-forward call the
  existing application-owned PlaybackCubit, so on-screen and media-session
  state remain one source of truth.
- Make AppButton an InkWell, preserving its pressed animation while giving
  every shared action native focus, keyboard and remote activation.

## Consequences

- No media, persistence or Jellyfin contract changes and no schema migration.
- Large Android tablets retain handheld behavior because the host, not screen
  dimensions, selects TV mode. Windows keeps its pointer/keyboard shell.
- Fire TV and Android TV use the same capability path without a Leanback UI
  dependency or Google service.
- Widget tests cover automatic selection, TV layout, initial focus, D-pad
  branch changes, Menu and media keys. Platform tests pin manifest declarations,
  native detection and banner dimensions. Android compilation verifies the
  merged host integration.
- Final store/device acceptance still requires a physical Fire TV: launcher
  presentation, overscan on the target television, on-screen keyboard entry,
  remote variants, media session behavior and background playback cannot be
  certified by widget tests.
