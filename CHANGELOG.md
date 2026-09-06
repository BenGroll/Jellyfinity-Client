# Changelog

All notable changes to Jellyfinity are documented here.

## v0.3.0 — Offline music hardening

Bug fixes, lifecycle hardening, and release hygiene on top of v0.2.3. This
is **not** the whole of `Roadmap to v0.3.md`'s v0.3.0 scope — the feature
deliverables it lists are still outstanding, and are named at the end of
this entry.

- **A retried download no longer splices two encodings together.** A
  partial file was keyed by track alone, with no record of the address its
  bytes came from. Pausing or failing a download at one download quality
  and retrying it at another appended the tail of the new encoding to the
  head of the old one, and the result completed, reported itself
  downloaded, and played as noise. `DownloadStorage` now records the
  source beside the partial and discards a partial fetched under a
  different one; a re-issued session token is explicitly *not* a different
  source, so an ordinary re-sign-in still resumes rather than starting
  over. A partial left by an older install carries no marker and is
  discarded once, costing one track a fresh start.
- **A connection returning mid-check no longer strands the download
  queue.** The worker's Wi-Fi-only gate and the connectivity listener both
  read the network and then wrote, unserialized. On a rapid transition the
  listener's release could land first and the worker's stale hold on top
  of it, leaving every request parked on "waiting for Wi-Fi" with good
  Wi-Fi and nothing left to wake it. Both now go through one lock and one
  answer per pass.
- **Now Playing no longer claims a transcode for a downloaded track.** The
  quality badge read the *streaming* preference, which
  `LocalFirstAudioSourceResolver` deliberately ignores when it plays a
  local file — so a downloaded lossless track announced itself as "AAC ·
  256 kbps" because of a preference that never touched it. The badge now
  answers to the download-quality preference when the track is on the
  device.
- The Downloads screen's Collections list keeps a stable order. It was
  built by walking maps whose iteration order shifts as records change
  state, so it reshuffled itself while a download ran; it is now grouped
  by kind and sorted by name, like the two sections either side of it.
- `DownloadsCubit` no longer accumulates abandoned-download ids for the
  life of the process. Only the transfer actually in flight is marked, and
  the mark is cleared however that transfer ends.
- Removed the `markUnavailable` flag from `ArtistRow`, `AlbumRow`,
  `TrackRow` and `PlaylistRow`. It was documented, threaded through, and
  set at every call site, but the shared row had been changed to a
  hardcoded "never dim" and ignored it entirely. `AlbumTile`, which does
  honour the flag, keeps it; `TrackRow.playable` remains the live
  mechanism for a row that genuinely cannot be tapped. No rendering
  changes.
- Added a CI workflow (format, analyze, test), which `CONTEXT.md` has
  required since v0.0.1 and which the repository did not have. Making the
  formatting gate pass reformatted 21 files that were already unformatted
  on `main`; those changes are whitespace only.
- Corrected `pubspec.yaml`'s version, left at the `flutter create` default
  of `1.0.0` through every release so far. `1.0.0` is reserved for the
  first public release.
- Gave this changelog per-version sections. Everything up to v0.1.0 was
  recorded without headings and is kept as one section rather than split
  on guesswork.

Still outstanding from v0.3.0's specification, all of it new behaviour
rather than repair: the entry-point audit (Now Playing, the queue and the
mini-player carry no download or offline state, and inline search has no
download action); batch retry and batch removal on the Downloads screen;
rendering `MediaAvailability.localOnly` as "Only on this device", which
v0.2.3 promised and no widget yet does; and reclaiming downloaded files
when an account or server is removed, which today leaves them on disk and
unreachable.

## v0.0.1 – v0.1.0 — Proof of concept

Recorded without per-version headings at the time. `ROADMAP.md` and
`Proof Of Concept Roadmap.md` carry the version-by-version scope; the
entries below are in the order the work landed.

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

## v0.1.1 — Streaming quality and transcoding

- Added streaming quality and transcoding (ADR-0015, v0.1.1):
  `StreamQuality` grows from direct-play-only to Lossless plus three AAC
  transcoded tiers (320/192/128 kbps), selectable from a new "Streaming
  quality" section in Settings and persisted like navigation mode. A
  transcode failure on the currently playing track retries once at the
  original file before being marked unavailable, rather than treating a
  transient failure as permanent. Now Playing shows the source file's own
  format/bitrate and, when a transcode is likely, what it is being
  transcoded to.

## v0.1.3 — Crossfade

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

## v0.1.4 — Volume normalization

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

## v0.1.5 — Lyrics

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

## v0.1.6 — Interface refresh

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

## v0.2.0 — Downloaded tracks and albums

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

## v0.2.1 — Downloadable playlists

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

## v0.2.2 — Artist downloads, download quality, and management

- Added artist downloads, download quality, and a Downloads screen
  (ADR-0022, v0.2.2), the third release in the offline-music arc:
  - `DownloadOwnerKind.artist` joins `track`, `album` and `playlist`
    with no change to the owner model. `downloadArtist` pages the
    artist's tracks one window at a time and requests each window as it
    arrives — a prolific artist is never loaded into memory — reusing any
    track a download already holds. `removeArtist` drops only the artist
    claim; a file another target keeps stays. No membership snapshot: an
    artist's order comes from release date and disc/track number, the
    same as an album's.
  - A download-quality preference, persisted independently of the
    streaming quality (`SettingsCubit`, default original/lossless). It
    applies to new and retried downloads and never re-fetches or rewrites
    a file already on the device. `SettingsCubit` became a
    `lazySingleton` so `PlaybackCubit` and `DownloadsCubit` read the same
    instance the settings screen writes to.
  - A Wi-Fi-only download preference (opt-in, default off). When it is on
    and the connection is metered or absent, a queued download moves to a
    new `DownloadState.waitingForNetwork` — a clearly paused request, not
    a failure — and resumes on its own when Wi-Fi returns or the
    preference is turned off. `connectivity_plus` sits behind a narrow
    `NetworkCondition` seam. Enforcement is foreground only, disclosed in
    the settings screen and ADR-0022, the same limit as the foreground
    download engine.
  - A Downloads screen reached from the sidebar: aggregate storage in
    use, an in-progress/needs-attention list with per-item retry, resume,
    cancel and remove, the downloaded albums/artists/playlists as
    tappable rows, and standalone songs. It holds no state of its own —
    every figure is derived from `DownloadsCubit`'s catalog, which gains
    `overallStatus`, `storageInUse`, `collectionOwners` and
    `standaloneTrackDownloads`.
  - `DownloadsCubit` now resolves the *remote* audio source under its
    named registration rather than the bare contract, so a retried
    download is re-fetched from the server at the current quality instead
    of resolving to the partial local file.
  - Added the `ACCESS_NETWORK_STATE` Android permission.

## v0.2.3 — Offline library and recovery

- Added the offline library and recovery release (ADR-0023, v0.2.3), the
  fourth in the offline-music arc — downloaded music you can find and
  trust when the server is away or has changed:
  - Downloads are now per-profile. Schema v6 adds an `account_key` to the
    primary key of `track_downloads`, `download_owners` and
    `playlist_download_members`; `DriftDownloadStore` scopes every read
    and write to the signed-in Jellyfin user, so two profiles on one
    server keep separate collections and neither sees, plays or removes
    the other's. `DownloadsCubit` rebuilds its catalog on a profile
    switch or sign-out. Downloads made before v0.2.3 are claimed by the
    first profile to sign in after the upgrade — the old single-bucket
    behaviour, carried forward, not lost.
  - The new `downloaded_collections` table stores a downloaded album's,
    artist's or playlist's name and artwork, recorded at download time
    and refreshed on an online open. A downloaded playlist shows its real
    name instead of a generic label, and a collection renders offline
    before its tracks have been browsed.
  - The library and search fall back to the profile's downloads through
    `DownloadsLibrarySource`, read as ordinary library windows. Artists
    and albums are browsable offline from a single downloaded track of
    theirs, not only from a whole-artist or whole-album download. A music
    search that fails whole offline falls back to those downloads when
    they match, so an offline search still finds playable music rather
    than only an error.
  - Opening one of those artists, albums or playlists offline now works
    too, not just finding it: the detail page renders from the downloads
    when nothing was ever saved for it. The part that is not on the
    device is one honest "N songs not available offline" / "N albums not
    available offline" line — the count, not a row per title the user
    never downloaded. Playlists fill from their membership snapshot the
    same way.
  - A "Work offline" switch in the sidebar deliberately puts the whole
    app offline — the library and search answer from the device, no
    server round-trips. With no connection it shows on and disabled. A
    new Settings choice, "Offline library", decides what offline shows:
    the whole cached library with download markers ("Show everything"),
    or only what is on the device ("Downloads only"). It applies only
    while offline. Switching on or off reloads every list already on
    screen, and the reloaded window reflects the mode it landed in even
    when the switch and the scope both fired on the same frame. See
    ADR-0023; this revisits `CONTEXT.md`'s "not a separate app mode"
    line, which is updated to match.
  - Downloaded albums and artists carry a small marker on their library
    tile or row and on their detail header.
  - A downloaded song plays from a single tap — on the Downloads screen's
    own song list, and in the library, album, playlist and search views
    even where the row is marked unavailable because the server dropped
    it or cannot be reached. A song that genuinely cannot play offline is
    greyed out in place instead.
  - The per-list "showing your saved copy" notice is replaced by one
    offline line under the shared search field, shown on every Home and
    Library tab. It is the only offline banner: its wording switches on
    the "Offline library" scope ("showing your saved library" /
    "showing downloaded music only") instead of the library page stacking
    a second line of its own. The search screen's "can't reach the
    server" state is likewise one line under its field rather than a
    full-page error and a red line under every category.
  - Opening a downloaded album or artist online reconciles its tracks
    against the server: one the server no longer lists is marked
    `server_gone` and shown as "Only on this device" — kept and still
    playable — not as a remote failure or by vanishing; one that
    reappears loses the mark. A playlist reconcile marks a
    removed-but-kept member the same way. Nothing local is ever deleted
    as a side effect of a sign-in, refresh or server removal.
  - `restore` verifies each completed download still has its file and
    re-queues any whose file has vanished, so a database/file mismatch
    can no longer leave a phantom "downloaded" track that plays silence.
  - A low-storage warning before a large download: `DownloadStorageProbe`
    (over `disk_space_plus`, behind a replaceable seam) backs
    `DownloadsCubit.storageWarning`, and the album, artist and playlist
    download controls ask the user to confirm past it. Advisory only —
    no automatic cleanup, and a platform that will not report free space
    never blocks a download.
  - `disk_space_plus` is a new dependency.
