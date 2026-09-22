# Jellyfinity v0.9.x specifications

Read only the assigned version. This arc deepens how users inspect and navigate
their music library. Every patch must use bounded server-side or indexed local
reads, preserve offline truth, support Android and Windows, and retain iOS.

## Big goal - Music library depth

Make large, imperfectly tagged Jellyfin music libraries feel intentional:
artists and albums have useful structure, artwork is dependable, navigation is
fast, and search stays musical rather than becoming a mixed-media dump.

## v0.9.0 - Rich music metadata contracts

**Goal:** Establish the read models required by richer album, artist, artwork,
sorting, filtering, and search experiences.

**Required:**

- Extend music domain models only with fields that presentation genuinely uses,
  separating album artist, contributing artist, release type, disc, date,
  genres, credits, identifiers, image roles, and source variants where Jellyfin
  exposes them reliably.
- Define absence and provenance for optional live, cached, downloaded, and
  local-only metadata; no UI may infer a fact from a missing field.
- Add paged/indexed repository contracts for release groups, appearances,
  credits, facets, sort keys, filters, and search categories without leaking
  Jellyfin DTOs.
- Version cached/downloaded metadata and migrate or rebuild it safely within
  profile/server boundaries.
- Test malformed and sparse libraries, compilations, multi-disc releases,
  duplicate names, large result sets, offline fallback, and older servers.

**Done when:** Later v0.9.x views can express rich music structure through
stable bounded contracts rather than one-off transport calls.

## v0.9.1 - Album presentation

**Goal:** Make an album page communicate the release and support listening
without flattening every album into the same track list.

**Required:**

- Present release identity, album artists, year/date, release type, genres,
  credits, duration, availability, quality/source variants, and artwork only
  when the model can support each fact honestly.
- Group and number multi-disc releases clearly while preserving true playback,
  playlist, download, and queue order.
- Handle compilations, missing discs, repeated tracks, alternate versions,
  partial server responses, and local-only members without losing usable rows.
- Keep primary play, shuffle, queue, playlist, Favorite, and download actions
  efficient across touch, pointer, keyboard, and D-pad use.
- Test compact/wide/TV layouts, long metadata, large albums, mixed availability,
  offline rendering, and action-to-queue behavior.

**Done when:** Album pages are informative and dependable enough to replace
Jellyfin Web for normal music inspection and playback.

## v0.9.2 - Artist presentation

**Goal:** Make an artist page a coherent view of that artist's place in the
user's library.

**Required:**

- Separate albums, singles/EPs, compilations, appearances, and songs when the
  server metadata supports the distinction; omit empty or unknowable groups.
- Add bounded top-song and discography sections with explicit sort/filter
  choices, independent loading states, and no whole-artist materialization.
- Present biography, genres, related artists, imagery, Favorites, availability,
  and library statistics with clear live/cached/offline provenance.
- Keep artist-wide play, shuffle, queue, playlist, and download actions bounded
  and explicit about which visible or queried scope they use.
- Test prolific artists, compilation-only appearances, split identities,
  missing metadata, pagination, offline downloads, and responsive layouts.

**Done when:** Users can understand and play an artist's library without a
single noisy list or ambiguous action scope.

## v0.9.3 - Artwork pipeline and presentation

**Goal:** Make music imagery sharp, stable, efficient, and honest across every
supported layout.

**Required:**

- Model artwork roles and requested display size explicitly; select server
  variants appropriate to phone, desktop, TV, and high-density displays.
- Deduplicate requests, bound memory/disk caching, cancel obsolete work, and
  avoid decoding full-resolution images for small rows.
- Preserve confirmed downloaded/local artwork, define refresh/staleness rules,
  and use deliberate neutral fallbacks without turning absence into an error.
- Apply consistent crops, aspect ratios, transitions, semantics, and palette
  extraction to library, detail, Home, search, queue, and player surfaces.
- Test corrupt images, server changes, offline starts, cache pressure, rapid
  scrolling, large displays, and platform decoder differences.

**Done when:** Artwork remains crisp and stable without causing layout shifts,
memory spikes, repeated network work, or misleading offline blanks.

## v0.9.4 - Sorting, filtering, and fast navigation

**Goal:** Make a 130k-song library as navigable as a small personal collection.

**Required:**

- Add domain-level, server-backed sort and filter specifications for music
  categories, exposing only combinations Jellyfinity can execute faithfully.
- Provide category-appropriate controls for artist, album, song, playlist,
  genre, decade, Favorite, downloaded, and availability views.
- Add fast alphabetic or equivalent position navigation where the data source
  can provide stable ordering, with keyboard and D-pad alternatives.
- Preserve selections and scroll position across refresh and layout changes;
  state must reset safely when profile, server, category, or filter changes.
- Test collation, symbols, numeric names, unknown metadata, huge libraries,
  empty filters, offline subsets, pagination, and accessibility.

**Done when:** Users can reach a known part of a large music library quickly
without client-side full-library sorting or filtering.

## v0.9.5 - Contextual music search

**Goal:** Make search precise enough for music discovery and retrieval while
remaining understandable across result types.

**Required:**

- Define a cancellable, paged music-search query with explicit categories for
  songs, albums, artists, playlists, genres, and other supported music facets.
- Add context-aware search from a category or detail scope, optional category
  switching, recent local queries, and clear active filters.
- Keep categories independently loading and failing; rank only within a named
  category and never blend unrelated entities into one opaque score.
- Preserve downloaded/local fallback, availability markers, partial results,
  and profile/server isolation. Recent queries contain no server credentials or
  cross-profile history.
- Test rapid typing, cancellation, pagination, duplicate names, diacritics,
  offline results, partial server failure, scale, and all input modes.

**Done when:** A user can find a song, album, artist, or playlist quickly and
always understands the scope and source of the results.

## Non-goals for v0.9.x

Movies, shows, global mixed-media search, external metadata databases, automatic
tag repair, server-library editing, and a generic media-domain redesign are
outside this arc.
