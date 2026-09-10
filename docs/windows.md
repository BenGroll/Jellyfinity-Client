# Windows

Use the same Flutter SDK as CI (3.44.7) with Visual Studio's Desktop development
with C++ workload and a Windows SDK. Enable Developer Mode if Flutter reports
that plugin symlinks are unavailable.

```powershell
flutter pub get
flutter run -d windows
flutter build windows --release
```

After adding native plugins, stop an older running copy and start again; hot
reload cannot register DLLs. Distribute the **whole**
`build/windows/x64/runner/Release` directory, including its DLLs and `data`
folder. The decoder is bundled; users do not need to install mpv separately.

For a labeled export, run `./build_exe.sh` in Git Bash on Windows. It builds
release mode and copies the complete runtime into a fresh folder under
`build/exe/`, labeled with the branch, commit and working-tree status. Run
`jellyfinity.exe` inside that folder and distribute the entire folder. Like
`build_apk.sh`, it supports `CLEAN=1` and `PUB_GET=1`; `MODE=debug` or
`MODE=profile` selects another build mode. Windows builds require the Windows
Flutter SDK and Visual Studio toolchain; run this script outside WSL.

Mouse-drag horizontal shelves, or use a trackpad/Shift + wheel. Library,
Favorites and detail collections have a Refresh button. Ctrl+F opens search,
Escape closes search, and Alt+Left goes back. The full player scrolls in short
windows and places a larger cover beside the controls in wide windows.
Library/Favorites tabs stay centered. Artist and album pages use blurred
artwork backgrounds; artist headers prefer Banner images, then Backdrop.
Minimize keeps music and downloads running; closing exits the app.
Interrupted downloads resume when reopened. Ethernet satisfies the Wi-Fi-only
download preference as it does on mobile.

## Automated checks

```powershell
flutter analyze
flutter test
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/windows_platform_test.dart -d windows --profile
```

The native test uses silent generated audio and a local HTTP server, creates a
unique temporary credential and audio directory, and cleans them up afterward.
It does not sign into Jellyfin or change saved accounts.

## Device acceptance

- Sign in, restart, switch accounts, and verify each profile's library,
  favorites, playlists, history and queue remain separate.
- Play original FLAC, MP3, AAC, Opus and a server-transcoded stream; seek,
  pause, skip, shuffle, repeat, reorder, Play Next, and remove queue entries.
- Listen across album boundaries with crossfade disabled, then enabled;
  verify gain normalization against tracks with known gain tags. Playlist
  prefetch is enabled, but the backend documents gapless behavior as
  experimental. A queue edit may briefly rebuffer on Windows.
- Use hardware media keys and the Windows media panel while minimized;
  check title, artist, artwork, pause and next/previous.
- Download tracks, albums, playlists and artists; pause/retry/cancel, restart,
  disconnect, then browse cached artwork and play downloads offline. Check
  plain and synchronized lyrics while connected.
- Resize the window, scroll long lists and shelves, refresh collections,
  edit the queue, and use search and keyboard navigation.

Playback uses the existing domain/application logic. Existing roadmap gaps
(such as playlist track reorder) remain outside this platform port.
