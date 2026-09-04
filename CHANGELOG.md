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
- Added the Music section (ADR-0012) — the first real library UI, and the
  second shell destination, which is what finally makes the bottom
  navigation bar appear. Artists, albums, songs and playlists as four
  independently paged tabs; artist, album and playlist detail screens
  that load their header and their children separately, so a cover and a
  title are on screen while a long track list is still arriving. Tapping
  a song opens its album — there is no player until v0.0.9, and a tap
  that looks like playback and is not would be exactly the guessing this
  project is trying to eliminate.
- Added music-scoped search: one debounced field, four server-side
  queries kept apart by category (`PHILOSOPHY.md` §8), a preview of each
  with "show all" leading to the ordinary paged list. One category
  failing does not fail the search, and a slow answer to an old query
  never overwrites a newer one.
- Search is a `searchTerm` on the existing `MusicLibraryRepository` and
  `PlaylistRepository` collection reads rather than a separate result
  type, so searching one category is an ordinary window with a term
  attached.
- Added `PagedCollectionCubit` and `PagedCollectionView`: one place for
  the states a large list has to get right — skeletons shaped like the
  content instead of a spinner, a failed next window that keeps every
  window before it, a refresh that never blanks the list, unreadable rows
  that keep their place and their markings, and prefetching that stays a
  screen ahead of the scroll. Nothing is sorted or filtered in Dart.
- Added the media metadata cache (schema v2: `cached_media_items`,
  `cached_collections`, `cached_collection_entries`). Jellyfinity now
  remembers the music it has browsed, in the order the server gave it,
  including the entries it could not read — so a library stays browsable
  when the server stops answering, and a playlist's numbering offline
  matches what the user saw online. What was browsed is cached, not the
  library: there is no background mirror of 130k songs.
- Added the read-through repositories ADR-0010 planned —
  `CachedMusicLibraryRepository`, `CachedPlaylistRepository` and
  `CachedMediaMetadataRepository` now resolve for their contracts and
  wrap the Jellyfin implementations. The fallback is limited to "the
  server never answered": a 404 is the server answering, and must not
  resurrect a deleted album. Searches are neither saved nor served from
  the cache.
- `Page` gained a `PageSource`, so a screen can say it is showing a saved
  copy rather than a current one, and cached media reads back as
  `remoteUnavailable`. A wholly cached list gets one notice above it
  rather than every row dimmed.
- Added the bounded artwork cache ADR-0010 deferred to this release: a
  count-bounded disk LRU plus an explicit ceiling on decoded images in
  memory. Nothing invalidates by hand — the Jellyfin image tag is already
  in the URL, so new artwork is a new cache key and the old file ages
  out. `MediaArtwork` asks the server for the size it will actually draw
  and reserves its box before loading, so a scrolling grid never
  reflows.
- Removing a saved server now also drops its cached library.
- Added a media-scale test (130k songs cached one window at a time, then
  a window read from the far end) and a v1 → v2 migration test against
  the committed schema snapshot.
- Added `cached_network_image` and `flutter_cache_manager` dependencies.
