# Changelog

All notable changes to Jellyfinity are documented here.

## Unreleased

- Initialized the Flutter Android and iOS application.
- Added the reproducible development container.
- Added Windows-hosted Android emulator support through ADB.
- Added the initial Jellyfinity development shell.
- Added the application architecture core: feature-first Clean
  Architecture direction (ADR-0001), `flutter_bloc` state management
  (ADR-0002), `get_it`/`injectable` dependency composition (ADR-0003), a
  shared `Result`/`Failure`/`Partial` model (ADR-0004), and privacy-safe
  logging/configuration conventions (ADR-0005), each with focused tests.
- Added navigation with `go_router` (ADR-0006): a composition-root
  `AppRouter`, an auth gate driven by a stubbed `SessionCubit`
  (`unauthenticated` → welcome, `authenticated` → shell), a
  `StatefulShellRoute` app shell (Home section only for now), and a
  not-found route.
- Added the `lib/design/` design system (ADR-0007): semantic tokens for
  colour, spacing, radii, typography, elevation, and motion, delivered as
  a `ThemeExtension` and read through `context.tokens`; dark-first light
  and dark themes; and shared UX primitives — `AppScaffold`, shimmering
  `AppSkeleton`/`AppSkeletonList`, `EmptyStateView`, `ErrorStateView`
  (with failure-aware retry), `UnavailableContent`, and `AppButton`.
- Replaced the placeholder development shell with the real welcome and
  Home screens built on the design system.
- Added the Jellyfin transport layer (ADR-0008) under
  `lib/infrastructure/jellyfin/`: a `dio`-based `JellyfinHttpClient` whose
  request surface returns `Result` and never leaks a `DioException`;
  centralized `JellyfinClientIdentity` building the Jellyfin
  `Authorization` header, with an `AuthTokenProvider` seam for v0.0.5;
  `dio` interceptors for the identity/auth header, debug request
  correlation, and bounded GET-only retry; `JellyfinServerUrl`
  normalization; `ServerVersion` plus a one-line `MinimumServerVersionPolicy`
  (floor: Jellyfin 10.11.6); a `json_serializable` `PublicSystemInfoDto`;
  `TransportErrorMapper` normalizing transport failures to the ADR-0004
  model; and `JellyfinServerProbe.validate()` to check a server is
  reachable, really Jellyfin, and supported.
- Added `UnauthorizedFailure` and `UnsupportedServerFailure` to the core
  `Failure` hierarchy (note added to ADR-0004).
- Added `dio`, `json_annotation`, and `json_serializable` (dev)
  dependencies.
- Added authentication, servers, and sessions (ADR-0009). `lib/domain/`
  gains its first content — the session concepts kept distinct
  (`JellyfinServer`, `JellyfinAccount`, `AuthSession`) and their
  contracts (`ServerRegistry`, `AccountStore`, `CredentialStore`,
  `JellyfinAuthenticator`). A real user journey now works end to end:
  enter a server address → validate it → sign in with a Jellyfin
  username/password (`AuthenticateByName`) → the session is restored on
  the next launch (no network call, so a currently-offline server does
  not block startup) → switch profile, sign out, or remove a saved
  profile/server from the new Accounts screen. Polished connecting and
  error states throughout; no raw exception text in the UI.
- Access tokens are stored in platform secure storage
  (`flutter_secure_storage`: iOS Keychain, Android Keystore-backed
  `EncryptedSharedPreferences`). The non-secret saved-servers/profiles
  registry uses a small JSON-file store behind the domain contracts as
  an explicit interim until the v0.0.6 database.
- `SessionAuthTokenProvider` replaces `NoAuthTokenProvider` as the
  transport layer's token source; `JellyfinHttpClient` gained a
  `postJson` surface.
- The router's onboarding flow (`/connect`, `/connect/sign-in`) and the
  `/accounts` screen; the welcome screen now starts the connect flow
  instead of a development shortcut.
- Added `flutter_secure_storage`, `path_provider`, and `uuid`
  dependencies.
- Added the local-data foundation (ADR-0010): a SQLite database via
  `drift` under `lib/infrastructure/persistence/database/`, with a
  forward-only migration policy (`schemaVersion` 1, committed schema
  snapshot in `drift_schemas/`, `PRAGMA foreign_keys` on). Schema v1:
  `saved_servers`, `saved_accounts`, and a typed `key_value_entries`.
- Replaced v0.0.5's interim JSON store: `DriftServerRegistry` and
  `DriftAccountStore` now back the unchanged `ServerRegistry` /
  `AccountStore` contracts, and a one-time `LegacyJsonImporter` moves any
  existing `servers.json` / `accounts.json` into the database at startup
  (renaming the files to `*.migrated`). `JsonStore`, `FileJsonStore`,
  `FileServerRegistry`, `FileAccountStore` and `PersistenceModule` are
  removed.
- The device id Jellyfinity reports to a server is now generated once and
  persisted (`DeviceIdentityStore`), closing the deferral in ADR-0008 and
  ADR-0009 — a server sees one stable device instead of one per launch.
- Added a typed `KeyValueStore` for small non-sensitive state (preferences,
  the device id, the active-account pointer). Secrets stay in secure
  storage.
- Documented cache semantics and the local/remote repository-source
  convention in ADR-0010; the artwork disk cache is specified but its
  implementation waits for v0.0.8, when artwork is first rendered.
- Added a representative-scale database test (`@Tags(['scale'])`): 130k
  rows, batched insert, indexed lookup, offset pagination.
- Added `drift` and `drift_flutter` dependencies (`drift_dev` for
  codegen); `drift` / `drift_dev` pinned to 2.34.0.
- Added Jellyfinity's media vocabulary (ADR-0011) in
  `lib/domain/media/`: `Artist`, `Album`, `Track`, `Playlist`, `Movie`,
  `Series`, `Season` and `Episode` over a shared `MediaItem`, plus
  `MediaImage`, `MediaAvailability`, `PlaybackProgress`, `ArtistRef` and
  the `Page`/`PageRequest` pair every collection is read through. Media
  is identified by `MediaId` — Jellyfinity's local server id together
  with the Jellyfin item id — so no bare, server-specific id is ever
  passed around.
- Added narrow media repository contracts —
  `MusicLibraryRepository`, `PlaylistRepository`,
  `MediaMetadataRepository`, `PlaybackProgressRepository` and
  `ArtworkResolver` — with Jellyfin-backed implementations under
  `lib/infrastructure/jellyfin/media/`. Every read is a windowed,
  server-sorted query; nothing offers "give me everything", and nothing
  filters a library in Dart.
- Added `BaseItemDto` and `BaseItemMapper`: one polymorphic DTO matching
  Jellyfin's item response, and the codebase's only translator from it
  to domain entities. It maps ticks to `Duration`, `UserData` to
  playback progress, and image tags to artwork (a song points at its
  album's cover, an episode at its show's poster, so an image is cached
  once rather than once per row). An item of the wrong type, or without
  an id or a name, becomes an `unavailable` entry on its page instead of
  a dropped row or a failed screen.
- Added `JellyfinMediaApi`: the single place that knows Jellyfin's query
  vocabulary, owner of the session-scoped HTTP client (rebuilt when the
  active profile moves to another server), and the guard that refuses to
  ask one server for another server's item.
- Added the `JellyfinSessionContext` seam (implemented by
  `SessionJellyfinContext` over `AuthSessionManager`), so the media
  layer can read the active server and user without infrastructure
  depending on the composition root — the same arrangement as
  `AuthTokenProvider`.
- Artwork resolves to a sized URL rather than being fetched; the bounded
  artwork cache lands in v0.0.8, behind the same contract.
- `JellyfinHttpClient` gained `send()` for endpoints whose answer is
  their status code — marking an item played or unplayed.
- Renamed every single-class file to `PascalCase` matching its class
  (e.g. `media_id.dart` → `MediaId.dart`); files with no class or more
  than one, and every `_test.dart` file, keep
  `lower_case_with_underscores`. Convention recorded in
  `CONTRIBUTING.md`; `flutter_lints`' `file_names` rule is disabled for
  it in `analysis_options.yaml`.
- Fixed the Android release build having no network access: the
  `INTERNET` permission, which Flutter only writes into the debug and
  profile manifests, is now declared in the main manifest. A release APK
  could not reach any server; a debug build on the same URL could.
- Added an Android network security config that permits cleartext
  traffic, so a release build can connect to the plain `http://` LAN
  servers the connect screen already accepts. HTTPS is still preferred
  wherever the server offers it.
- Added audio playback (ADR-0013): `just_audio` for decode/gapless
  playback, `audio_service` for background execution and lock-screen/
  notification media controls. `JustAudioPlaybackEngine` is both the
  `PlaybackEngine` implementation and the `audio_service` handler
  itself, kept deliberately ignorant of queues, shuffle or repeat so a
  future engine (e.g. `media_kit`) is a one-class swap.
- Added Jellyfinity's own playback queue in `lib/domain/playback/`:
  `PlaybackQueue`/`QueueEntry` (pure, engine-free shuffle/repeat/reorder
  logic), the `PlaybackEngine` contract, `AudioSourceResolver`
  (mirrors `ArtworkResolver`, resolves a track's authenticated stream
  URL), and `QueueRepository`. Persisted in schema **v3**'s
  `QueueEntries` table — a self-contained denormalized snapshot per
  entry, since a queued track is not guaranteed to have gone through
  the v0.0.8 cache.
- `JellyfinAudioSourceResolver` builds the direct-play stream address
  (`static=true`, no transcoding); the session token travels as an
  `api_key` query parameter, since a stream URL is fetched by the
  native platform player directly rather than through
  `JellyfinHttpClient`'s interceptors.
- `PlaybackProgressRepository` gained `reportStart`/`reportProgress`/
  `reportStop` over Jellyfin's `/Sessions/Playing` endpoints, closing
  the seam its own v0.0.7 doc comment left open — Jellyfin's resume
  position and played state now agree with what Jellyfinity actually
  played.
- Added `PlaybackCubit` (`lib/app/playback/`), the same architectural
  slot as `SessionCubit`/`AuthSessionManager`: the only thing that
  talks to both the queue and the engine, resolving sources, computing
  play order (including shuffled), persisting the queue, and marking a
  failed track unavailable in place and moving on rather than clearing
  the queue.
- Added the mini-player (in the shell, above the bottom nav, shown only
  with a non-empty queue), the full Now Playing screen (artwork, seek,
  transport, shuffle/repeat), and the queue screen
  (`ReorderableListView`, remove, jump to any entry). Both Now
  Playing and the queue are root routes so they cover the bottom nav
  from any tab.
- Every track tap across the music screens — album/playlist detail, the
  Songs tab, and search — previously dead per ADR-0012 ("no player
  until v0.0.9"), now starts playback with whatever list was already
  loaded as the queue. Album/playlist headers gained a Play button;
  `TrackRow` gained an optional overflow menu for Play Next and Add to
  Queue.
- Android: `MainActivity` now extends `AudioServiceActivity`; the
  manifest gained the foreground-service permissions and the service/
  media-button-receiver entries `audio_service` needs. iOS: `Info.plist`
  gained `UIBackgroundModes = [audio]`. Gapless playback and background/
  lock-screen behavior are verified on-device rather than by an
  automated test — nothing in this stack runs outside a real device.
- Added swappable navigation modes (ADR-0014): a persistent header
  (search field always visible, never a subscreen; a row of media-type
  "pills" beneath it) versus a unified mode with no pill row, chosen in
  a new Settings screen and persisted via `KeyValueStore`. Only Music is
  a real pill today — no fake placeholders for the unimplemented Movies/
  TV/Audiobooks/Ebooks types, and no "Combine" UI, since there is
  nothing to combine yet.
- Added the app sidebar (`AppSidebar`, a standard `Drawer` on `AppShell`
  — default edge-swipe plus a menu button, no custom gesture code):
  Accounts (the existing screen, unchanged) and the new Settings screen.
- Search moved inline: `MusicSearchPage` (a pushed page) is retired in
  favor of `InlineMusicSearch`, swapped in for the header in place so
  the bottom nav and mini-player stay visible underneath it. Reuses
  `MusicSearchCubit` and the categorized-results widgets unchanged.
- The Music tab is renamed Library, scoped to whichever media-type pill
  is active (today, always Music); every `/music` route and name is
  renamed to `/library` to match (`MusicPage.dart` → `LibraryPage.dart`).
- `test/support/pump_app.dart` now sets a realistic phone viewport
  (390×844) for every full-app test — the default 800×600 test surface
  left too little room once the persistent header, mini-player and
  bottom nav were all present, which could silently mis-hit-test a tap
  on content lower in the screen.
- Replaced the placeholder Flutter launcher icon with the real
  Jellyfinity app icon. Android ships density-specific legacy and round
  bitmaps plus an adaptive icon (navy `#000080` background, monochrome
  foreground) for API 26+, and the manifest now declares a `roundIcon`
  and the display label `Jellyfinity`. iOS gets the full `AppIcon`
  asset catalogue, with every image flattened to opaque RGB so the
  1024px marketing icon carries no alpha channel. The web `manifest.json`
  and `index.html` lose their "A new Flutter project" boilerplate.
- Added streaming quality and transcoding (ADR-0015, v0.1.1):
  `StreamQuality` grows from direct-play-only to Lossless plus three AAC
  transcoded tiers (320/192/128 kbps), selectable from a new "Streaming
  quality" section in Settings and persisted like navigation mode. A
  transcode failure on the currently playing track retries once at the
  original file before being marked unavailable, rather than treating a
  transient failure as permanent. Now Playing shows the source file's own
  format/bitrate and, when a transcode is likely, what it is being
  transcoded to.
- Added crossfade (ADR-0016, v0.1.3), configurable from a new Crossfade
  section in Settings: a switch plus a 1-12 second length slider,
  persisted like the other preferences. `just_audio` has no crossfade of
  its own and one native player cannot overlap two items of its own
  playlist, so `JustAudioPlaybackEngine` now runs **two decks** — both
  holding the whole source list, one active at a time — and equal-power
  ramps between them, cueing the incoming source to position zero so the
  overlap behaves the same for a transcoded stream as for a direct-play
  file. With crossfade off it is one deck on the unchanged single-player
  path, so gapless playback is preserved by construction. Repeat-one
  suppresses crossfade, since a queue repeating one track never reaches
  the next source the engine would otherwise fade into.
