# Jellyfinity v0.3.x–v0.4.0 specifications

Read only the assigned version. Each version is one complete, user-visible
increment. All versions require focused changes, behavior tests, a current
changelog entry, and passing CI. A durable technical choice receives an ADR.

This arc remains music-only. Movies and television stay out of scope, as
they have been since v0.1.0 — this arc is about making the music
Jellyfinity already plays easier to return to.

## Big goal — a front door worth opening

Jellyfinity today opens on a placeholder: an icon, a sentence, and a
button that points at the Library tab. Everything a person did last time
— what they played, where they stopped, what they starred, what their
server just added — is either already in the database or one query away,
and none of it is on screen.

This arc turns Home into the place the app actually starts: what you were
listening to, what you played recently, what is new on your server, and
what you have marked as yours. It also gives Favorites somewhere to live —
today a track can be starred from three screens and then never found
again.

Two constraints shape the whole arc:

- **Nothing here is a new content type or a new playback capability.**
  Every section is built from data Jellyfinity already collects
  (`PlaybackProgress`, `isFavorite`, the persisted queue, the download
  catalog) or from one additional query against the library it already
  browses. If a section needs a new subsystem, it is the wrong section.
- **Home must be honest offline.** `ADR-0023` made offline a deliberate
  mode with a "downloads only" scope. Every section added here has to say
  something truthful in that mode — which for most of them means showing
  the part that is on the device and saying so, not disappearing.

A modular, user-reorderable Home (`OUTLOOK.md` §9) is **not** this arc.
Strong defaults first; customization is only worth building once there is
something to customize.

## v0.3.1 — Listening history

**Goal:** Record what the user actually listened to, so later versions can
show it.

**Required:**

- Add a domain contract for listening history: what was played, when, and
  enough identity to render a row without asking the server. Keep Jellyfin
  and persistence details out of it, as with every other seam here.
- Record a play when playback genuinely happens, not when something is
  queued or skipped past. Define and document the threshold; a track the
  user skipped after two seconds is not something they listened to.
- Store history in the local database, **bounded** — `CONTEXT.md` forbids
  unbounded local growth, and a year of listening is not a useful list.
  Decide and document the cap and the eviction rule.
- Scope history to the signed-in profile, the same way downloads are
  (v0.2.3, ADR-0023). One profile's listening must never appear under
  another's, and signing out must not expose it.
- Collapse repetition at the source or at the read, whichever is cleaner:
  playing an album straight through is one thing the user did, not twelve.
  A history that lists the same album twelve times is not a feature.
- Record history for local playback too. A downloaded album played on a
  plane is listening, and history that only works online would be the one
  part of Jellyfinity that forgets what offline is.
- Test the play threshold, the bound and its eviction, profile isolation,
  offline recording, collapsing, and migration.

**Done when:** Jellyfinity durably knows what this profile listened to,
online and off, within a bounded local record — with nothing yet showing
it.

## v0.3.2 — Continue listening and recently played

**Goal:** Make Home open on what the user was doing.

**Required:**

- Replace the Home placeholder with a real, scrolling Home built from
  sections. Establish the section pattern the rest of the arc uses: each
  section loads, empties, fails, and refreshes independently, and one dead
  section never takes the screen down (`PHILOSOPHY.md` §2, the same rule
  `MusicSearchCubit` already follows for search categories).
- Add **Continue listening**: the persisted queue (v0.0.9) is already
  restored across restarts, so offer to resume it — what was playing, how
  far in, and one tap to carry on. If there is nothing to resume, the
  section is absent, not empty.
- Add **Recently played** from v0.3.1's history: the albums, playlists and
  artists the user actually returned to, newest first, tappable straight
  into the thing itself.
- Both sections must render offline from local data, marking what is not
  playable rather than hiding it — and under the "downloads only" scope
  (ADR-0023), show only what can actually play.
- Home's existing "Browse music" affordance may go once there is something
  better to look at, but the Library must stay one obvious tap away.
- Test section independence, resume behaviour, empty and offline states,
  the downloads-only scope, and that a failing section leaves the others
  usable.

**Done when:** Opening Jellyfinity shows what the user was listening to
and what they have played lately, with the server up or down.

## v0.3.3 — Recently added

**Goal:** Show what the server has gained since the user last looked.

**Required:**

- Add a **Recently added** section: albums (and, where it reads well,
  artists) newest-first by the date the server acquired them.
- Extend the media query surface to support descending sort. `queryItems`
  currently hardcodes `sortOrder: Ascending`, which is exactly wrong for
  this; the change is small but it is a shared seam, so it must not
  regress the existing library, artist and playlist queries.
- Cache the section's answer like every other library read, so a cold
  offline open still shows the last known "recently added" rather than an
  error — clearly marked as the saved copy, per the existing
  cache-fallback behaviour.
- Recently added is a *server* fact. When Jellyfinity is deliberately
  offline it must not imply freshness it cannot check.
- Test descending sort against the shared query surface, the cached
  fallback, empty libraries, and the offline presentation.

**Done when:** A user who added music to their server last night sees it
on Home this morning.

## v0.3.4 — Favorites as a place

**Goal:** Give the star a destination.

**Required:**

- Favorites can be set from Artist, Album and Now Playing (v0.1.6,
  ADR-0019) and then never browsed. Add a Favorites destination that lists
  favorite artists, albums and tracks, reachable from normal music
  navigation — not buried in Settings.
- Extend the media query surface with Jellyfin's `IsFavorite` filter, the
  same shared-seam care v0.3.3 takes with sort order.
- Add Favorites sections to Home, consistent with the section pattern
  v0.3.2 establishes.
- Settle the offline question honestly. ADR-0019 deliberately does **not**
  persist favorite state to the offline cache, which means an offline
  Favorites view has nothing to read. Either extend the cache (a schema
  migration, with the account-scoping the download tables already model)
  or state plainly in the UI that Favorites needs the server. Do not show
  an empty list and let the user conclude they have none — that is exactly
  the failure `CONTEXT.md` names first.
- Test the filter against the shared query surface, favoriting and
  unfavoriting reflecting in the destination, the empty state, and
  whichever offline behaviour is chosen.

**Done when:** A user can star music from anywhere and then actually find
it again, with the offline story stated rather than implied.

## v0.3.5 — Related artists and albums

**Goal:** Make one thing lead to the next, from the user's own library.

**Required:**

- Add related artists to Artist detail and similar albums to Album detail,
  from Jellyfin's own similarity endpoints where the server offers them.
- Ground it in the user's library. `PHILOSOPHY.md` and `OUTLOOK.md` §13
  both draw the line here: no external recommendation service, no
  tracking backend, nothing that requires sending listening data anywhere.
- A server that answers nothing useful is a normal outcome, not a failure.
  The section is absent, not broken, and never shows a spinner forever.
- Where it earns its place, surface the same relationships on Home — but
  only if it reads as useful rather than as filler.
- Test present/absent/failed similarity responses, the offline state, and
  that a missing endpoint on an older-but-supported server degrades
  quietly.

**Done when:** Finishing an album offers somewhere obvious to go next,
drawn entirely from the user's own server.

**Stretch:** Genre or decade entry points, if they can be added without a
new subsystem.

## v0.4.0 — Home completion

**Goal:** Release a Home that holds up on a real library, on a real
device, in every state Jellyfinity can be in.

**Required:**

- Audit every section against the loading, empty, partial, offline,
  cached, unavailable, unauthorized and failed states `CONTEXT.md`
  enumerates. A section that has never been seen with an empty library,
  a dead server, or a single-album collection is not finished.
- Verify Home at scale. `CONTEXT.md` treats 130k songs as normal; Home
  issues several queries at once on the app's most-opened screen, and must
  not become the reason a large library feels slow. Bound what each
  section fetches and confirm it with a scale test.
- Confirm history stays bounded in practice over a long simulated run, and
  that profile switching swaps Home wholesale with no leakage between
  profiles.
- Establish device validation for the whole arc on Android and iOS: cold
  start, offline start, downloads-only scope, profile switch, and a
  representative large library.
- Add regression tests for the complete primary flows, and update the ADRs
  and changelog the final architecture requires.

**Done when:** Home is the screen a user is glad to land on, at any
library size, in any connection state, on both platforms.

## Non-goals for v0.3.1–v0.4.0

Movies, television, video playback and video downloads remain outside this
arc, as they have since v0.1.0. Also out of scope: a user-configurable or
reorderable Home (`OUTLOOK.md` §9), external recommendation services or
any tracking backend (§13), social sharing (§7), collaborative playlists
(§8), theme editing (§10), and multi-server unified libraries (§14).

Listening history is a local convenience for showing the user their own
activity. It is not analytics, it is never transmitted anywhere, and no
version in this arc may make it so.

## Decisions to settle during implementation

- **Where history comes from.** Jellyfin already records
  `UserData.LastPlayedDate` and play counts, and Jellyfinity already
  reports playback to it (v0.0.9). Server-derived history would need no
  new table; locally recorded history is exact, works offline, and is
  Jellyfinity's own. The choice must be made on offline behaviour and
  large-library cost, not on which is quicker to write, and recorded in an
  ADR either way.
- **The play threshold.** Some duration or fraction of a track counts as
  "listened to". Pick it from how the queue actually behaves — including
  crossfade (ADR-0016), which ends a track early by design.
- **Whether Favorites joins the offline cache.** ADR-0019 deferred this
  deliberately to keep v0.1.6 free of a migration. v0.3.4 either takes the
  migration on or documents why Favorites remains online-only; both are
  defensible, but the UI must say which is true.
