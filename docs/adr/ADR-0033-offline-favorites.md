# ADR-0033: Offline favorites

## Status

Accepted

## Context

`Roadmap to v0.5md`'s "Offline Favorites" (v0.4.3) asks for the heart to
remain trustworthy when connectivity is intermittent: a user can favorite
or unfavorite while offline, the intent reconciles once a session can
reach the server again, and Favorites, its Home strip, details and search
stay mutually consistent through the offline change, a reconnect, an app
restart, an account switch and a server removal.

The code did not match ADR-0019/ADR-0028's own description of it. Those
said the detail-page heart is hidden on a cached/offline copy and that a
favorite write is only ever attempted while a screen shows a live-fetched
item. Neither is true of the current `AlbumDetailPage`/`ArtistDetailPage`/
`NowPlayingPage`: the heart renders unconditionally, and
`CachedMediaMetadataRepository.item` (which `NowPlayingDetailsCubit` and
the queue's on-demand fetch both go through) already falls back to the
metadata cache like every other repository here. Offline, the heart was
visible, always showed unfavorited (`cached_media_items` never carried
`isFavorite`, per ADR-0019), and a tap attempted a server write that could
only fail — the exact "ambiguous or lost interaction" this version exists
to remove. This ADR treats the code as ground truth and closes the gap
rather than restoring the originally-described hiding behavior.

## Decision: `CachedFavoritesRepository` gains a pending-intent fallback

`FavoritesRepository.setFavorite`'s signature is unchanged — a caller
still just gets back whether the intent was accepted. Online, nothing
changes. Offline (`OfflineMode.status.isOffline`, the same signal every
other cached repository already reads), there is no server to attempt the
write against, so none is attempted:

- The change is written straight into `cached_favorites` — the same
  mirror a successful online write already updates (ADR-0028) — so
  Favorites, its Home strip and a reopened detail page agree with it
  immediately, before any reconnect.
- The change is also recorded in a new table, `pending_favorite_intents`
  (schema **v10**): `(account_key, item_id)` primary key, plus
  `server_id`, `kind`, the intended `favorite` value, and `updated_at`.
  One row per item — a second offline toggle overwrites the first rather
  than queuing behind it, so only the latest local intent is ever
  replayed. "A later local action wins" falls out of that upsert with no
  ordering logic of its own, and it is what makes rapid toggling coalesce
  into one eventual write.
- Requires both a signed-in profile and a `kind`. Without a profile there
  is nothing to scope the intent to; without a kind (the interface's
  existing "omit it and only the server write is attempted" escape hatch,
  ADR-0028) there is nothing to enqueue. Either missing refuses the write
  outright rather than silently doing nothing.
- A fresh **online** success also clears any pending intent left over for
  the same item, so a stale offline intent recorded before an online
  change (and not yet replayed) cannot later overwrite it on a reconnect.

The table is purely additive, the same shape every prior schema bump
here has taken (ADR-0023, ADR-0028): one new table, nothing existing
touched, an upgrading install starts with nothing pending.

## Decision: `PendingFavoritesSync` replays, `FavoritesRevisionCubit` announces it

A new app-level singleton, started once from `bootstrap.dart` alongside
the session and playback restores, does the other half: read a signed-in
profile's pending intents and attempt each one against the real server
(`JellyfinFavoritesRepository`, unwrapped — replaying through
`CachedFavoritesRepository` would just re-queue an already-pending
intent). It has two triggers, either of which can be the one that
matters:

- `OfflineMode` flipping from offline to online — the ordinary "the
  connection came back" case.
- `SessionCubit` reaching `SessionStatus.authenticated` — covers
  restoring a session that was already online (no offline-to-online
  transition ever fires) and switching to a different profile that has
  its own pending intents.

Reconciliation reads and writes only the *currently active* profile's
intents, re-checked before every request in the batch: switching accounts
mid-flush stops the flush rather than finishing it against the wrong
session, so nothing here can leak a change to a profile or server it was
not meant for. A request that still fails (the server genuinely rejects
it, or the connection drops again mid-batch) leaves that intent exactly
where it was, retried on the next trigger — "a server failure remains
retryable" is simply "nothing deletes the row".

`FavoritesRevisionCubit` (ADR-0028) is bumped once a batch reconciles
anything, the same signal a toggle made anywhere else already sends. It
is promoted from a widget created inline in `JellyfinityApp` to a
registered `@lazySingleton`, resolved once at the composition root like
every other cross-cutting cubit there (`SessionCubit`, `PlaybackCubit`,
…) — the minimum change needed for something outside the widget tree to
share the same instance the Favorites destination and Home already
listen to.

## Decision: a reopened detail page overlays the same truth

`MediaCacheStore.readItem` gains an optional `accountKey`. When given, it
overlays that profile's row in `cached_favorites` onto the cached
item's `isFavorite` — which a favorite toggled offline also updates, so
a detail page reopened offline (or after an app restart, still offline)
shows the same heart it did a moment ago instead of the unconditional
`false` `cached_media_items` itself carries (ADR-0019's mapper decision,
unchanged). `MediaCacheMapper.toItem` gains a matching `isFavorite`
parameter, defaulting to `false` for the ordinary case.

Both callers that fall back to a cached single item — `CachedMusicLibrary
Repository._item` (the Album/Artist detail headers) and
`CachedMediaMetadataRepository.item` (Now Playing and the queue's
on-demand track fetch) — pass their already-computed `accountKey`
through. `CachedMediaMetadataRepository` gains a `JellyfinSessionContext`
dependency for this, the same seam the other cached repositories already
hold. Search needed no change: it was already server-only offline
(ADR-0010) and answers "the server is needed" rather than fabricating
results, so there is nothing there for a stale favorite to corrupt.

## Decision: the banner is the "visible" half of "retryable and visible"

The Favorites destination shows a small, dismissal-free note — "N
favorites waiting to sync" — whenever the active profile has anything
pending, backed by a new `PendingFavoritesCubit` that counts
`pending_favorite_intents` and refreshes on the same revision bump. It
disappears the moment nothing is pending. This is deliberately the only
UI surface for pending state: the heart itself already looks right the
instant it is tapped (the optimistic toggle, and `cached_favorites`
agreeing everywhere that reads it), so the banner's job is narrow —
saying plainly that the server has not actually heard about it yet,
rather than leaving that fact implicit the way `CONTEXT.md`'s "never
leave users guessing" rules out.

## What this does not change

- Reconciling a genuine, non-connectivity server rejection while online
  (the existing "online but the request fails" path) is unchanged: the
  optimistic heart still reverts, exactly as before this version. Nothing
  here touches that case — it is a live attempt talking to a reachable
  server, not an offline promise.
- Movies, TV, and any kind outside `MediaCacheMapper.cachedKinds` are
  unaffected; a heart is only offered on Artist, Album and Track today,
  unchanged from ADR-0019.
- Downloads-only scope narrowing (ADR-0028's Home strip decision) is
  untouched and needed no new code: it already filters whatever
  `cached_favorites` reports, which now simply includes offline changes
  too.

## Tests

- `media_cache_store_test.dart` — pending-intent persistence, coalescing
  a second offline toggle of the same item, per-profile isolation,
  `clearServer` cleanup, and the `readItem` favorite overlay (with and
  without an `accountKey`, and across profiles).
- `app_database_migration_test.dart` — the v9 → v10 upgrade, and that an
  existing favorite survives it.
- `cached_favorites_repository_test.dart` — records a pending intent and
  updates the cache without touching the server while offline; coalesces
  rapid offline toggles; refuses the write with nobody signed in; never
  records another profile's intent; a fresh online success clears a
  stale pending one for the same item.
- `pending_favorites_sync_test.dart` — replays and clears a pending
  intent on reconnect; bumps the revision cubit on success; reconciles
  immediately on start when already online; a server rejection leaves the
  intent pending; does nothing while still offline; never replays into
  another profile's intents; reconciles a different profile's intents
  once it signs in.

Android and Windows: nothing here is platform-conditional — Drift/SQLite,
the offline/session seams and the Favorites UI already behave identically
on both, and this version adds no new platform surface.

## Consequences

- Schema **v10**: `pending_favorite_intents`, one index, an additive
  migration step, a schema snapshot and a migration test.
  `MediaCacheStore` gains `recordPendingFavorite`, `pendingFavorites` and
  `clearPendingFavorite`; `readItem` gains an optional `accountKey`.
- `FavoritesRevisionCubit` moves from an inline widget-tree value to a
  registered singleton, constructed once in `main.dart` and handed to
  `JellyfinityApp` like every other cross-cutting cubit.
- `CachedFavoritesRepository` gains an `OfflineMode` dependency;
  `CachedMediaMetadataRepository` gains a `JellyfinSessionContext` one.
- One new app-level singleton (`PendingFavoritesSync`), started from
  `bootstrap.dart`; one new cubit (`PendingFavoritesCubit`) and banner on
  the Favorites destination.
- A profile's stale `pending_favorite_intents` rows are not individually
  purged when only that one profile (not its server) is removed — the
  same convention `cached_favorites`/`cached_media_items` already follow
  (ADR-0028): harmless orphaned rows under an `account_key` that can
  never be reissued, cleaned up in bulk only when the owning server goes.
