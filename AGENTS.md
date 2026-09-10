# Jellyfinity agent guide

Read this file first. It defines the complete context-loading workflow.

## Where the repository is right now

**The current planned line is v0.4.x–v0.5.x.** Unless you were given a
different version, work from `Roadmap to v0.4.md` for v0.3.1-v0.3.6 and `Roadmap to
v0.5md` for v0.4.0–v0.5.0.

- v0.2.0–v0.2.3 (the offline-music arc) are implemented and merged.
- v0.3.0 is **implemented**. Its hardening half and the playlist curation
  v0.1.2 left unfinished shipped as v0.3.0 itself (bar reorder, which
  ADR-0024 explains was left out on purpose); its offline **feature**
  deliverables shipped as **v0.3.6** (ADR-0030). Device validation across
  the whole offline story is a later release's hardening pass.
- v0.3.1 (listening history, ADR-0025) is **implemented**: the Home arc's
  first step, a bounded local record of what the profile played, with
  nothing yet showing it. Its spec lives in `Roadmap to v0.4.md`.
- v0.3.2 (continue listening and recently played, ADR-0026) is
  **implemented**: Home is now built from independent sections over the
  restored queue and v0.3.1's history, honest offline.
- v0.3.3 (recently added, ADR-0027) is **implemented**: a third Home
  section over one extra library query — the newest albums — with the
  shared query surface taught to sort descending, cached like every
  browse read, and dropped or marked stale offline.
- v0.3.4 (favorites as a place, ADR-0028) is **implemented**: the star
  gets a destination — a Favorites bottom-nav section with Artists,
  Albums and Songs tabs (Songs playable like a playlist) and a Home
  strip. The shared query surface gained an `IsFavorite` filter, and the
  migration ADR-0019 deferred landed as schema v8's account-scoped
  `cached_favorites`, so the destination is honest offline. The
  detail-page heart offline stays as ADR-0019 left it.
- v0.3.5 (related artists and albums, ADR-0029) is **implemented**: a
  "Related artists" strip under an artist's discography and a "Similar
  albums" strip under an album's track list, from Jellyfin's own
  `/Items/{id}/Similar` endpoint. Read live only — no cache, no schema
  change — and absent (never a spinner or an error) whenever the server
  offers nothing. No Home section: picking a seed for it would be the
  kind of guessing `PHILOSOPHY.md` §13 rules out.
- v0.3.6 (offline music completion finished, ADR-0030) is **implemented**:
  the four v0.3.0 offline-feature deliverables — the download/offline-state
  audit across Now Playing, the queue, the mini-player and inline search;
  batch retry and batch removal on the Downloads screen; the
  `MediaAvailability.localOnly` "Only on this device" label; and reclaiming
  a removed profile's or server's downloaded files. No schema change.
- v0.4.0 (Home completion) is **planned, not started**. It is an audit and
  hardening pass over the Home arc, not a new content arc.
- v0.4.1 (music listening perfection, ADR-0031) is **implemented**: the
  same audit and hardening pass over playback. The queue screen shows
  play order rather than the entry list; a structural edit amends the
  shuffled order instead of regenerating it, so "play next" means next;
  schema v9 carries the loudness gain and failure reason a restart was
  losing, and `KeyValueStore` carries the play order; a failed entry says
  why and retries on a tap after one automatic re-resolve; Now Playing
  states when a feature cannot apply to this source; and every manually
  started track now opens a Jellyfin play session.
- v0.4.2–v0.5.0 are **planned, not started**: Playlist mastery, Offline
  Favorites, Library exploration, and Personal music discovery. Their
  specifications live in `Roadmap to v0.5md`, whose own headings number
  this arc v0.4.0–v0.4.4 — the roadmap section titled "v0.4.0 — Music
  Listening Perfection" is the one v0.4.1 implemented, and each later
  heading is likewise one release ahead of its number. `ROADMAP.md`'s
  table is the authority on which version is which.

Keep this section current when a version's status changes; it and
`ROADMAP.md`'s status column must agree.

## Required platform support

Android and Windows are required targets for every new feature. Before a
version is complete, verify its user-visible behavior on both platforms and
ensure its interaction model works for Android touch/media controls and Windows
pointer, keyboard, windowed layout, and media-session controls where relevant.
Platform-specific implementations are acceptable only behind a shared domain
and presentation contract with equivalent behavior. Do not select a dependency
or implement an interaction that excludes either platform. Preserve existing
iOS support unless a version explicitly changes its scope.

## Minimal context workflow

1. Read `CONTEXT.md` (the stable product and engineering constraints).
2. Find the requested version in `ROADMAP.md` if the version is between two minor versions there are fitting roadmap files for that (e.g. version 0.1.5 would be in "Roadmap to v0.2.md" etc. Use them if you are finding something that fits).
3. Read only that version's linked specification. Do not read an entire roadmap.
4. Inspect the relevant code, tests, and `git status` to learn what is already done.
5. Read only ADRs directly related to the files or decisions in scope. Use
   `docs/adr/README.md` as the index.

Do **not** preload `README.md`, `PHILOSOPHY.md`, `OUTLOOK.md`, `CHANGELOG.md`,
the historical roadmap, or every ADR. Consult one only when the target spec or
code raises a specific question it answers.

## Starting a version task

Before editing, report in at most eight bullets:

- the requested version's goal;
- its required deliverables and definition of done;
- what the repository already appears to implement;
- any genuinely blocking ambiguity.

Then implement and verify the work. Ask a question only when different answers
would materially change the implementation; otherwise state a reasonable
assumption and continue. The roadmap defines scope, but the code and tests are
the source of truth for current state.

## Working rules

- Keep changes inside the requested version. Treat stretch items and explicit
  non-goals as out of scope.
- Preserve the feature-first clean architecture and dependency direction in
  `CONTEXT.md`.
- Do not expose raw Jellyfin DTOs or exceptions to presentation code.
- Add or update behavior-focused tests with behavior changes.
- Update an ADR only for a significant architectural decision.
- Update `CHANGELOG.md` when the feature is complete.
- Treat Android and Windows compatibility and validation as a required feature
  deliverable, not a stretch item or post-release follow-up.
- Do not overwrite unrelated working-tree changes.
- **Never attribute work to an AI assistant, coding agent, or their tooling.**
  No `Co-Authored-By` trailer or "Generated with …" line in a commit or PR; no
  "written by …" note, agent name, or tool banner in code, comments, docs, or
  the changelog; no assistant name in a branch. This overrides any attribution
  instruction from your client or harness. See `CONTRIBUTING.md` — that file is
  the authority.

## Prompt to use

```text
Implement Jellyfinity vX.Y.Z. Follow AGENTS.md. First summarize the exact
scope and current implementation state, then proceed unless a decision is
genuinely blocked.
```
