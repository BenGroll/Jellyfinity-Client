# ADR-0029: Windows platform support

## Status

Accepted

## Context

The generated Windows runner starts, but the mobile playback dependencies do
not supply a Windows decoder or system media controls. Disk-space reporting
also depends on a mobile-only plugin. Existing application-owned queues,
downloads, account isolation and library caches must retain their contracts.

## Decision

- Keep `JustAudioPlaybackEngine`, including its two-deck crossfade and gain
  normalization. Initialize `just_audio_media_kit` only for Windows and bundle
  `media_kit_libs_windows_audio`; Android and iOS retain their native players.
  Enable playlist prefetch. This avoids duplicating the playback state machine
  and gives local files and streams the same decoder support.
- Add `audio_service_win` for Windows system media controls. Compile that
  plugin with C++20 for current MSVC/WinRT coroutine compatibility. Version
  0.0.3 is vendored with its MIT license: fix wide-string logging for C++20,
  dispatch media-button callbacks on the platform thread, and handle absent
  artwork. This keeps the build reproducible without changing the pub cache.
- Replace the native playlist on Windows queue edits, retaining the selected
  occurrence and position computed by the application. The adapter's incremental
  insertion/move indices differ from just_audio's; using them can desynchronize
  native playback from the visible queue. Replacement can briefly rebuffer during
  an edit. Ordinary playback keeps its preloaded playlist.
- Keep `DownloadStorageProbe` as the domain boundary. On Windows, a small
  runner method channel calls `GetDiskFreeSpaceExW` for the application support
  directory, returning bytes available to the current user on that volume.
  Failed probes remain unknown. Recognize Windows disk-full write errors too.
- Keep the existing Windows implementations of secure storage, Drift/SQLite,
  path_provider, connectivity and the artwork cache. No account or cache
  migration is needed.
- Adapt interaction at the widget layer: mouse-drag shelves, explicit desktop
  refresh, keyboard search/back navigation, and a bounded, scrollable full
  player for short windows.

## Verification and limits

Windows joins Linux in regression CI and builds a release executable. A native
integration test exercises credentials, storage, local Unicode file paths, HTTP
audio, seek, pause, queue replacement and both crossfade decks without a server.
See `docs/windows.md` for commands and the remaining manual acceptance checks.

Gapless audibility, perceived crossfade quality, hardware media keys and real
server codec/transcode combinations require device testing; unit tests cannot
establish those. Minimize keeps playback/downloads running. Closing the window
exits; no tray process or background download service is introduced.
