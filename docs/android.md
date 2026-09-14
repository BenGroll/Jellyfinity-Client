# Android

See `README.md`'s Android Development section for emulator/toolchain setup.
For a labeled test build, run `./build_apk.sh`; see its header comment for
ABI and clean/pub-get options. Physical devices work over USB or wireless ADB.

## Automated checks

Run `flutter analyze` and `flutter test` for behavior changes. There is no
native Android integration test yet (unlike `integration_test/windows_platform_test.dart`);
add one alongside the next change that needs a real Android host to verify.

## Device acceptance

- Sign in, restart, switch accounts, and verify each profile's library,
  favorites, playlists, history and queue remain separate.
- Play original FLAC, MP3, AAC, Opus and a server-transcoded stream; seek,
  pause, skip, shuffle, repeat, reorder, Play Next, and remove queue entries.
- Download tracks, albums, playlists and artists; pause/retry/cancel, restart,
  disconnect, then browse cached artwork and play downloads offline.
- Background the app while playing: verify the notification/lock-screen
  controls, headset and Bluetooth buttons keep controlling this device, and
  that playback survives Doze and a process kill/relaunch.
- While this device is remote-controlling another one (v0.5.6): press
  notification/lock-screen/Bluetooth/headset controls — they must reach the
  controlled device, never this device's own dormant local queue (v0.5.7,
  ADR-0041). Background the app, let Doze engage, and toggle Wi-Fi/mobile
  data while controlling and while being controlled; presence should
  reconnect or name the device as ended, never show stale state as live.
  While playing locally and backgrounded, verify this device still appears
  in another device's picker rather than going dark (v0.5.8, ADR-0042) —
  and that it drops off once playback actually stops.
  Check the device picker and remote Now Playing at phone and tablet sizes,
  in both rotations, and with system text scaling turned up. Use this
  Android device as the controlled target from another Android device, then
  from a Windows one, in both directions.

- v0.6.0: raise and lower this device's own volume from another device's
  Now Playing/mini-player while this device is the controlled target —
  the physical volume rocker should move and the on-screen level should
  track it. Start playing something on another device, then press play on
  a song/album/playlist here; confirm the takeover dialog names the other
  device, that confirming actually stops it there, and that cancelling
  leaves it untouched. Open the Remote destination and confirm this
  device, and the other one, both list correctly. From the Remote
  destination, tap "Play on all devices"; confirm a group starts, the
  other device joins and plays the same queue, and that leaving the group
  returns this device to independent playback without disturbing the
  other one.

Playback uses the existing domain/application logic. Existing roadmap gaps
remain outside this platform port.
