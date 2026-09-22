# Jellyfinity v0.10.x specifications

Read only the assigned version. This arc completes Home and personal discovery
in chronological releases, replacing the unfinished v0.4.0 and v0.5.0 slots.
Every patch must remain private, explainable, profile/server-scoped, bounded for
large libraries, and useful in honest offline states.

## Big goal - Personal music experience

Turn the listener's own library, history, Favorites, downloads, and Jellyfin
relationships into a Home and discovery experience that feels personal without
tracking, a proprietary service, or invented certainty.

## v0.10.0 - Home completion

**Goal:** Complete the requirements formerly assigned to v0.4.0 and make Home
trustworthy before adding more personalization.

**Required:**

- Audit every music Home section across loading, empty, partial, offline,
  cached, unavailable, unauthorized, failed, and sparse-library states.
- Bound and independently schedule every query so concurrent Home loading does
  not penalize a 130k-song library or let one failed section block another.
- Preserve useful section results through refresh, connectivity changes, and
  transient failures while clearly identifying cached or offline content.
- Verify history bounds over long simulated use and replace Home wholesale on
  profile/server switch without data, scroll, or recommendation leakage.
- Complete Android and Windows cold-start, offline, downloads-only, profile
  switch, and representative scale acceptance; retain iOS behavior.

**Done when:** Home is a fast, stable starting point in every supported state
and the old v0.4.0 specification can be considered fully superseded.

## v0.10.1 - Listening history as a destination

**Goal:** Give users a useful and controllable view of the local listening
record that already powers Continue Listening and Recently Played.

**Required:**

- Add a paged history destination grouped by useful time context, with filters
  for supported music entities and links back to playable library details.
- Distinguish a completed listen, partial session, resumed context, unavailable
  server item, and local-only item without fabricating server history.
- Let the active profile remove entries, clear a bounded range or all history,
  and understand how this changes Home and future recommendations.
- Keep history local, bounded, profile/server-scoped, and free of telemetry;
  account/server removal must clean up only matching records.
- Test long histories, repeated sessions, crossfade thresholds, offline
  playback, missing media, deletion, restart, and accessible navigation.

**Done when:** A listener can inspect and control the exact local history used
by Jellyfinity without exposing it or confusing it with Jellyfin analytics.

## v0.10.2 - Private recommendation candidates and ranking

**Goal:** Complete the requirements formerly assigned to v0.5.0 through a
transparent, bounded recommendation layer.

**Required:**

- Derive candidates only from the active profile's listening history,
  Favorites, downloads/playable library, and Jellyfin related-item endpoints.
- Record provenance and explanation data with every candidate so presentation
  never has to reverse-engineer why an item appeared.
- Prefer diversity across seeds, artists, albums, recency, and already-played
  items; omit weak results instead of filling a quota.
- Bound histories, seed counts, server requests, candidate pools, ranking work,
  cache lifetime, and offline computation for normal large libraries.
- Isolate unsupported or failed Jellyfin endpoints and provide honest cached or
  download-based candidates without transmitting user activity.
- Test ranking invariants, provenance, sparse libraries, repetition, endpoint
  failure, offline mode, account isolation, and deterministic fixtures.

**Done when:** Jellyfinity can produce credible, explainable next-listen
candidates privately and the old v0.5.0 specification is fully superseded.

## v0.10.3 - Discovery surfaces and explanations

**Goal:** Put private recommendations where they help without turning every
screen into an algorithmic feed.

**Required:**

- Add independently loading Home sections and a bounded discovery destination
  for supported recommendation families.
- Name the reason and source in user language, such as a related artist or a
  recent listen, without overstating confidence or exposing internal scores.
- Keep direct play, shuffle, queue, Favorite, download, dismiss/refresh, and
  detail navigation consistent with ordinary library surfaces.
- Let users suppress an unsuitable candidate or seed locally and reversibly;
  feedback tunes local results and is never uploaded as analytics.
- Omit empty families, preserve other sections through partial failure, and
  show cached/offline scope explicitly.
- Test independent state, stale candidates, disappearing media, interaction
  effects, compact/wide/TV layouts, and accessibility.

**Done when:** Discovery offers useful choices with understandable reasons and
never makes Home less reliable or private.

## v0.10.4 - Music Home section control

**Goal:** Let users shape the music Home they return to while retaining strong
defaults and bounded composition.

**Required:**

- Define a versioned Home-layout preference containing only registered music
  section identifiers, visibility, and order.
- Add accessible enable/disable and reorder controls with reset-to-default,
  preview, validation, and protection for required navigation affordances.
- Keep each enabled section independently owned and loaded; reordering widgets
  must not merge their state or trigger unnecessary refetches.
- Reconcile new, removed, or renamed section identifiers across upgrades without
  losing the rest of the user's layout.
- Scope layout preferences appropriately across profiles/devices and document
  that choice in an ADR; never synchronize them accidentally through Jellyfin.
- Test malformed preferences, upgrades, all-hidden attempts, drag/keyboard/D-pad
  reorder, responsive layouts, and state preservation.

**Done when:** Users can choose and order their music Home sections without
turning Home into an unsafe general-purpose page builder.

## v0.10.5 - Personalization hardening

**Goal:** Make Home, history, recommendations, discovery, and layout control one
dependable private system.

**Required:**

- Exercise long-running listening, history edits, recommendation refresh,
  dismissals, Home customization, offline transitions, and account switching
  together.
- Validate absence, sparse and huge libraries, repeated artists, partial server
  support, clock changes, cache expiry, app upgrade, and corrupted preferences.
- Bound database growth, query counts, memory, CPU, artwork work, and startup
  latency; Home must remain useful before every personalized section finishes.
- Complete Android, Windows, and television interaction/layout acceptance and
  preserve iOS behavior.
- Update privacy documentation and add failure-injection, migration, integration,
  and end-to-end tests without adding analytics or a cloud dependency.

**Done when:** Personalization improves everyday listening without compromising
Home reliability, privacy, scale, offline behavior, or user control.

## Non-goals for v0.10.x

External recommendation services, social feeds, collaborative filtering across
users, cross-server history, global theme editing, arbitrary Home widgets,
movies, and shows are outside this arc.
