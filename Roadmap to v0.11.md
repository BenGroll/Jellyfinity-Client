# Jellyfinity v0.11.x specifications

Read only the assigned version. This arc makes the completed music product feel
native on every supported form factor. Shared domain and presentation contracts
come first; platform-specific behavior remains behind them.

## Big goal - Platform-native music experience

Jellyfinity should be recognizably the same music application on Windows,
Android, Android TV/Fire TV, and iOS without behaving like one layout stretched
across every screen and input method.

## v0.11.0 - Adaptive music shell and input contracts

**Goal:** Establish one explicit adaptive structure for the complete music
experience before platform-specific completion.

**Required:**

- Inventory every destination, overlay, dialog, player, queue, picker, search,
  selection mode, and settings flow added through v0.10.x.
- Define layout capabilities from window constraints and host-reported
  television mode, never by guessing platform from width.
- Centralize semantic commands for navigation, activation, playback, search,
  selection, reorder, dismiss, and contextual actions so touch, pointer,
  keyboard, D-pad, and media keys reach the same application behavior once.
- Preserve state and focus when layouts change through resize, rotation,
  display attachment, or television-mode recreation.
- Add shared responsive, focus, semantics, and input-contract tests before
  specializing any platform.

**Done when:** Every music workflow has an adaptive layout and command contract
that platform implementations can complete without forking domain behavior.

## v0.11.1 - Windows music workspace

**Goal:** Make Windows a genuine desktop music application for sustained use.

**Required:**

- Add a persistent desktop composition for primary navigation, library context,
  queue/Now Playing access, and the active local or remote player without nested
  cards or phone-only navigation.
- Support documented keyboard shortcuts, context menus, hover/focus states,
  multi-select modifiers, accessible reorder, and drag-and-drop where it
  materially improves queue or playlist work.
- Keep narrow, snapped, maximized, scaled, and multi-display windows usable;
  persist only safe window preferences and recover off-screen placement.
- Integrate Windows media-session controls, audio-device changes, minimize,
  sleep/wake, and app exit with exactly one playback/control path.
- Validate installer/bundle behavior, file picking, background downloads,
  cross-device playback, large-library performance, and keyboard-only flows.

**Done when:** Windows users can browse, curate, download, and control music
efficiently without encountering a stretched mobile interface.

## v0.11.2 - Android phone and tablet completion

**Goal:** Complete the whole music product for Android touch and mobile
lifecycle behavior.

**Required:**

- Refine compact and expanded touch layouts, rotation, predictive/gesture Back,
  system text scaling, edge insets, keyboard appearance, and selection flows.
- Integrate local and remote playback with foreground service, notification,
  lock-screen, headset, Bluetooth, audio focus, calls, and becoming-noisy events
  through one authoritative route.
- Complete durable download scheduling, permission/system-policy messaging,
  Doze recovery, connectivity transitions, process recreation, and low-storage
  behavior on supported Android versions.
- Verify deep navigation, account changes, offline start, large libraries, and
  background activity after the OS reclaims non-playing UI state.
- Add native/widget tests and physical phone/tablet acceptance across supported
  Android versions and representative screen classes.

**Done when:** Android remains coherent through real touch, media, network,
background, and process lifecycle events across every music feature.

## v0.11.3 - Android TV and Fire TV completion

**Goal:** Complete the entire music library and player as a dependable 10-foot
experience.

**Required:**

- Extend ADR-0036's shared television path across playlists, downloads,
  discovery, search, settings, device selection, dialogs, and every v0.7-v0.10
  destination.
- Guarantee explicit initial/restored focus, spatially predictable traversal,
  scroll-to-focus, visible focus contrast, overscan-safe layout, and readable
  type for every state.
- Route D-pad, select/controller A, Menu, Back, transport, seek, and supported
  volume keys once while respecting keys owned by Android/Fire OS.
- Handle on-screen keyboard, sleep/wake, display state, background playback,
  network loss, process reclaim, launcher re-entry, and long-lived sessions.
- Complete automated host/widget coverage and physical Android TV and Fire TV
  acceptance without Google Play Services.

**Done when:** Every music workflow is comfortably usable from a television
remote and the TV remains a trustworthy local or connected player.

## v0.11.4 - iOS music compatibility completion

**Goal:** Preserve and validate the existing iOS music client through the full
pre-v1 feature set.

**Required:**

- Audit navigation, safe areas, text scaling, gestures, document/image picking,
  secure credentials, audio session, interruption, route change, background
  playback, and supported download lifecycle behavior.
- Keep shared feature behavior equivalent while using iOS-native system media
  integration and clear platform-specific limitations.
- Verify database and file migrations, local-only downloads, offline mode,
  playlists, Home/discovery, and account isolation on supported iOS versions.
- Add iOS-targeted unit/widget coverage that can run in ordinary CI and define
  the macOS/Xcode build and physical-device acceptance matrix.
- Do not claim connected-player/controller completion unless separately
  promoted; local playback must remain fully supported.

**Done when:** Existing iOS support is demonstrably preserved for the complete
local music experience and its remaining platform limits are documented.

## v0.11.5 - Accessibility and input acceptance

**Goal:** Make the same complete music workflows perceivable and operable across
supported assistive technologies and input methods.

**Required:**

- Audit semantics, labels, roles, values, announcements, traversal, focus
  restoration, error association, and live-state updates across the app.
- Support large/scaled text without overlap, clipping, hidden actions, or lost
  context; respect reduced motion and contrast needs.
- Ensure every pointer or drag action has keyboard and D-pad-accessible
  equivalents where those inputs are supported.
- Test screen-reader traversal, keyboard-only Windows use, switch/semantic
  activation on mobile, D-pad TV use, high contrast, reduced motion, and maximum
  supported text scale.
- Maintain an explicit acceptance checklist and regression suite for every
  primary browse, curate, download, playback, discovery, and account flow.

**Done when:** A user can complete every primary music workflow without relying
on sight, precise touch, pointer-only gestures, or animation.

## Non-goals for v0.11.x

New music-domain features, a separate TV application, platform-exclusive
libraries, Linux support, synchronized multi-room playback, movies, and shows
are outside this arc.
