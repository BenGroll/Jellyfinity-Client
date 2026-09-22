# Jellyfinity v0.7.x specifications

Read only the assigned version. This arc turns the existing dependable manual
playlist editor into a complete music-curation system. Every patch is usable on
its own and must preserve profile/server isolation, offline honesty, large-list
bounds, Android and Windows behavior, and existing iOS support.

## Big goal - Playlist intelligence

Make playlists powerful enough for deliberate library organization without
turning them into an opaque service. Manual playlists remain ordinary Jellyfin
playlists. Smart playlists are transparent Jellyfinity-owned rules that publish
a normal playlist snapshot back to the user's server.

## v0.7.0 - Bulk music selection and playlist actions

**Goal:** Let users curate more than one song at a time from the places where
they already browse music.

**Required:**

- Add an application-level selection model keyed by stable media identity and
  scoped to the active page, profile, and server.
- Support accessible multi-select in song lists, search results, album tracks,
  artist songs, Favorites, Downloads, and playlist rows where the action is
  valid.
- Add selected songs to an existing or new playlist in displayed order, with
  explicit handling for duplicates, unavailable rows, partial success, cancel,
  navigation, and account switch.
- Keep selection bounded and page-aware for large libraries; never load a whole
  result set merely because selection mode started.
- Test touch, pointer, keyboard, D-pad-safe exit behavior, ordering, duplicate
  identity, partial failure, and profile/server isolation.

**Done when:** A user can select a meaningful group of visible songs and add it
to a playlist once, with predictable order and an honest result.

## v0.7.1 - Playlist artwork management

**Goal:** Let a user recognize and personalize playlists visually.

**Required:**

- Add domain contracts for reading, replacing, and removing playlist artwork
  without exposing Jellyfin upload DTOs or transport errors to presentation.
- Support image selection, preview, crop where needed, upload progress, retry,
  replacement, and removal using formats and size bounds Jellyfin accepts.
- Refresh playlist rows, details, Home entries, cached metadata, and downloaded
  collection identity after a successful change.
- Preserve the last confirmed image during failure or offline use; pending
  artwork must never masquerade as a server-confirmed change.
- Validate Android document picking and Windows file picking; preserve iOS
  behavior behind the same domain contract.

**Done when:** Playlist artwork can be changed from Jellyfinity and every
playlist surface converges on the confirmed image without losing offline state.

## v0.7.2 - Smart playlist rules and preview

**Goal:** Define understandable automatic playlists before any background
refresh can mutate a server playlist.

**Required:**

- Define a versioned, profile/server-scoped smart-playlist rule model using
  bounded music predicates Jellyfin can query or Jellyfinity can evaluate from
  bounded local history, Favorites, downloads, and cached metadata.
- Support useful composition such as all/any groups, inclusion and exclusion,
  stable sorting, a result limit, and deterministic randomization where offered.
  Do not ship an arbitrary scripting language.
- Build a rule editor with validation and a paged preview that names the source
  and scope of each rule and distinguishes live, cached, partial, and offline
  results.
- Persist drafts separately from active definitions. Invalid, incompatible, or
  newer rule versions remain recoverable and never evaluate as an empty list.
- Test serialization, migration, bounds, deterministic ordering, missing
  metadata, offline evaluation, account isolation, and editor accessibility.

**Done when:** A user can build, understand, save, and preview a smart playlist
without changing any server playlist yet.

## v0.7.3 - Smart playlist publication and refresh

**Goal:** Turn a saved smart definition into a normal Jellyfin playlist that
stays predictably synchronized.

**Required:**

- Materialize an activated definition into a clearly marked Jellyfinity-managed
  Jellyfin playlist, retaining a stable link between definition and output.
- Compute additions, removals, and order changes from paged inputs and apply the
  smallest safe mutation set. A refresh must be idempotent and resumable.
- Make ownership explicit: managed output is read-only in Jellyfinity until the
  user converts it to a manual playlist; manual edits from another client are
  reported as a conflict before replacement.
- Refresh on demand and at safe foreground reconciliation points. Scheduling
  and background download behavior belong to v0.8.x.
- Preserve the last confirmed output on evaluation or server failure and show
  definition, preview, publication, and sync states independently.
- Test retry, duplicate delivery, concurrent server edits, renamed/deleted
  output, large libraries, unsupported rules, and account switching.

**Done when:** A smart definition can publish and refresh a stable ordinary
Jellyfin playlist without hidden destructive edits or whole-library loading.

## v0.7.4 - Playlist-system hardening

**Goal:** Make manual, downloaded, and smart playlists behave as one dependable
curation system at realistic scale.

**Required:**

- Audit create, rename, delete, add, bulk add, remove, reorder, artwork, smart
  refresh, download, queue-origin, and cross-device playback flows together.
- Make duplicate appearances, missing entry ids, unavailable items, mixed media,
  server-side edits, and partially readable playlists explicit and safe.
- Verify cached and downloaded playlist identity after rename, artwork change,
  smart refresh, server deletion, reconnect, app restart, and account removal.
- Bound reads, previews, diffs, mutations, and UI rendering for very large
  playlists; preserve cancellation and progress for long operations.
- Complete Android and Windows interaction and failure-path acceptance, retain
  iOS behavior, and add migration, integration, and regression coverage.

**Done when:** Users can build and maintain manual or smart playlists without
needing Jellyfin Web and without losing order, identity, or offline trust.

## Non-goals for v0.7.x

Collaborative playlists, cross-user editing, cross-server playlist identity,
external recommendation services, automatic download synchronization, video
playlists, and a general automation language are outside this arc.
