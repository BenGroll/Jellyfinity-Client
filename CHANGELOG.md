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
- Added volume normalization (ADR-0017, v0.1.4), configurable from a new
  Volume normalization switch in Settings. Reads Jellyfin's own
  `NormalizationGain` — server-side loudness analysis when available,
  else an embedded ReplayGain tag — already sent on every track
  response, so no extra request or minimum-version bump was needed.
  `JustAudioPlaybackEngine` folds the gain-adjusted volume into every
  place it already sets `AudioPlayer.volume`: steady state, every
  natural gapless transition, and both ends of the crossfade ramp, so
  the two features share one volume seam instead of fighting over two.
  Gain is only ever applied as attenuation, never a boost, to avoid
  clipping a track with no limiter downstream; a track with no reported
  gain plays unchanged rather than being guessed at.
- Added lyrics (ADR-0018, v0.1.5), reached from a new lyrics button in Now
  Playing's app bar. Jellyfin's `/Audio/{itemId}/Lyrics` endpoint answers
  with a line list that carries per-line timing only when the source
  lyrics file has it, so Jellyfinity decides plain vs. synchronized per
  track rather than as a single app-wide choice: synchronized scrolling
  and highlighting only when every line is timed and the timestamps never
  run backwards, plain lyrics otherwise. A 404 (no lyrics file, or the
  track itself is gone) is treated as the empty state the roadmap asks
  for, not an error; the Lyrics view otherwise shows a loading skeleton or
  a retryable failure like every other on-demand detail screen.
- Added an interface refresh (ADR-0019, v0.1.6) across Settings, Home,
  Artist, Album, Now Playing, Queue, and Playlist:
  - Settings' streaming-quality picker is a dropdown, with the selected
    tier's description shown beneath it, instead of one radio row per tier.
  - Home's search field is a fully rounded pill; the media-type pills are
    smaller.
  - The Artist page shows the artist's backdrop image and overview above
    its discography, alongside its album/song counts and total playtime
    (`ArtistStats`, computed live), plus a favorite toggle.
  - The Album page replaces its single Play button with a centered Play, a
    Shuffle button, and an overflow menu (Add to playlist, Add to queue)
    that act on the whole album; its artist credit is now a link; it gets
    a favorite toggle. The Playlist page gets the identical treatment.
    Add to playlist uses a new minimal `PlaylistRepository.addTracks`
    write seam — the rest of v0.1.2's playlist-curation writes (create,
    rename, delete, reorder, remove) remain unimplemented.
  - Now Playing's artist and album lines are links (resolved on demand,
    same as ADR-0015's track-source lookup); its background is a heavily
    blurred, scaled copy of the current artwork; the source-format line is
    now a stacked container/bitrate label with a Lossless-or-transcode
    badge; its app bar gains the same track overflow menu (Play Next / Add
    to Queue) library rows already have, and a favorite toggle. Opening an
    artist/album link closes the player first — a `go_router` limitation
    pushing a shell-nested route directly from Now Playing's root route,
    documented in ADR-0019.
  - The Queue's clear action is a plain "X" with a confirmation prompt
    instead of one-tap clearing; it shows the queue's remaining runtime at
    the top; each row gets a drag handle so reordering starts there
    instead of anywhere on the row.
  - Favorite state and the artist stats are read live from the server only
    — never added to the offline cache — and hide themselves on a cached/
    offline screen rather than showing a stale or guessed answer; showing
    who created a playlist was investigated and dropped, since neither
    Jellyfin's item response nor its dedicated Playlists endpoint exposes
    an owner.
- Follow-up fixes to the v0.1.6 interface refresh, from a first testing pass:
  - Home's media-type pills size their label and selected checkmark from
    content rather than a fixed pixel height, so neither gets clipped.
  - The streaming-quality dropdown shows a rough data-usage-per-hour
    estimate for each tier alongside its name.
  - The Album and Now Playing pages: clickable artist/album names drop
    their underline (the accent color already reads as a link); the
    track title, artist, and album text are larger; Now Playing's heart
    moves next to the title and its Lyrics/Queue actions fold into the
    overflow menu, leaving one icon in the app bar; the Album page's
    heart moves down next to Shuffle/Play/overflow instead of the app
    bar, with Play staying centered; Now Playing's background blur is
    stronger.
  - Fixed a bug where toggling shuffle (or any other queue edit) could
    make the currently playing track briefly jump to full volume before
    settling back — `JustAudioPlaybackEngine` was re-levelling volume off
    of `just_audio`'s transient, mid-reorder index reports, which could
    momentarily disagree with the not-yet-updated source list.
  - Fixed crossfade producing an audible stutter instead of a fade: when
    preparing the standby deck's network stream took longer than the
    outgoing source had left to play, the outgoing deck had already
    gaplessly advanced on its own, and starting the overlap anyway played
    the same source twice at once (ADR-0016). The preload lead is also
    widened from 5 s to 10 s so this is hit less often.
- Added downloaded tracks and albums (ADR-0020, v0.2.0), the first
  release in the offline-music arc:
  - New `lib/domain/downloads/` vocabulary: `TrackDownload` (a
    denormalized snapshot, the download counterpart to `QueueEntry`),
    `DownloadOwner`/`DownloadOwnerKind` (why a file is kept — a set,
    since the same track can be wanted on its own and via its album),
    `DownloadState`/`DownloadFailureReason`, `DownloadCatalog` (what a
    collection's downloads add up to, with failures named rather than
    averaged away), and the `DownloadStore`/`DownloadEngine` seams.
  - Schema v4 adds `track_downloads` and `download_owners` — ordered,
    migratable, additive per ADR-0010's policy.
  - `HttpDownloadEngine`: a foreground `dio`-based engine with HTTP
    Range resume, cancellation, atomic completion (rename on finish),
    and partial-file cleanup, behind a replaceable `DownloadEngine`
    seam — the roadmap's documented-foreground-only interim, since an
    Android+iOS resume/cancellation proof of a background-transfer
    dependency was not possible in this environment (ADR-0020).
    `DownloadStorage` keeps audio under application support, not a
    disposable cache — downloaded media is first-class local media.
  - `DownloadsCubit` runs downloads one at a time, oldest request
    first; resumes any download a fresh process finds still marked
    "downloading" from its partial bytes on disk; and supports pause,
    retry, retry-all, and remove (dropping one owner, or every claim).
  - Playback prefers a completed download over a stream via
    `LocalFirstAudioSourceResolver`, a decorator over the existing
    `AudioSourceResolver` — the queue, crossfade, and normalization
    pipeline are unchanged; only the resolved address differs.
  - Track rows and album headers gain a download control that both
    shows the state and is the action for it (download / stop / resume
    / remove-with-confirmation / retry), plus an album-wide aggregate
    summary.
  - `InsufficientStorageFailure` joins the core `Failure` hierarchy
    (ADR-0004) as its own distinct, user-actionable outcome.
- Added downloadable playlists (ADR-0021, v0.2.1), the next release in
  the offline-music arc:
  - `DownloadOwnerKind.playlist` joins `track` and `album` with no
    change to the owner model — "remove this playlist" drops the
    playlist claim from each member, and a file a standalone download or
    another downloaded playlist still wants is kept.
  - Schema v5 adds `playlist_download_members`: the ordered membership
    snapshot, one row per downloadable member, additive per ADR-0010.
    It records the order the user arranged — separate from the per-track
    owner rows, the same split `cached_collection_entries` uses — so a
    later server-side edit reconciles against it rather than rewriting
    it.
  - `DownloadsCubit` gains `downloadPlaylist` (pages the playlist and
    requests each page as it arrives, reusing a track already
    downloaded), `removePlaylist`, and `reconcilePlaylist` — the diff
    against the server that queues members added to the playlist, drops
    the claim on ones removed, rewrites the snapshot to the server's
    order, and reports the counts. Reconcile refuses to run against a
    cache-served read, and `retryAll` already covered the roadmap's
    "download all available" stretch item.
  - The playlist header gains a download control mirroring the album's,
    plus the aggregate summary. It differs where a playlist must:
    "downloaded" means a snapshot exists, and its menu offers "Check for
    changes." Opening a downloaded playlist online reconciles it once
    and reports what changed in a dismissible message — the roadmap's
    other reconcile trigger; there is no background auto-sync.
  - `CachedPlaylistRepository` falls back to the download snapshot when
    the server is unreachable and the metadata cache has been evicted,
    so a downloaded playlist still plays in order offline. A downloaded
    member plays through the unchanged v0.2.0 local-first path.
