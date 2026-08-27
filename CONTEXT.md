# Jellyfinity — Agent Context

## What Jellyfinity Is

Jellyfinity is a Flutter-based, free/open-source Jellyfin client primarily targeting **Android and iOS**.

Core product promise:

> **Make a self-hosted Jellyfin server feel like a premium streaming service.**

The client should not feel like a website or home-server admin interface. It should feel polished, responsive, predictable, and trustworthy.

Minimum initially supported server version:

> **Jellyfin 10.11.6**

Primary real-world test library:

- ~130k songs;
- ~500 movies;
- ~4k TV episodes.

Treat this as normal scale, not an edge case.

---

## Core Product Rules

### 1. Never leave the user guessing

Always make state clear.

Distinguish loading, empty, partial, offline, cached, unavailable, failed, unauthorized, downloading, downloaded, etc.

Prefer skeletons and known page structure over generic full-screen spinners.

Partial success beats total failure.

If 1 track of 12 is unavailable, show the album and the 11 usable tracks; visibly mark the unavailable one.

### 2. Premium UX is functional

Polish, feedback, loading behavior, transitions, error states, caching, and perceived reliability are part of feature completion.

### 3. Music, movies, and TV are first-class

Music is the initial focus and should eventually feel closer to Spotify/SoundCloud quality than typical Jellyfin music UX.

Movies and TV must later become equally native.

### 4. Offline is media availability, not a separate app mode

Media may be:

- remote only;
- local + remote;
- local only;
- remote unavailable;
- partially available.

Downloaded content survives server deletion and becomes **Only on Device** unless explicitly removed.

### 5. Privacy/open source

No ads, no paid tiers, no user-data business model, no unnecessary cloud dependency, no unnecessary telemetry.

### 6. Customization is important

Long-term: extensive theme/layout customization through structured design tokens and serializable themes, not arbitrary CSS.

### 7. Scale intelligently

Never assume full libraries can be loaded into memory.

Use pagination, lazy loading, server-side filtering, indexed persistence, virtualized lists, bounded caches, etc.

---

## Architecture Direction

Preferred architecture:

> **Feature-first Clean Architecture with shared domain/infrastructure modules where they genuinely span features.**

Dependency direction:

```text
UI
 ↓
Presentation
 ↓
Domain / Repository Contracts
 ↑
Infrastructure Implementations
```

Do not let widgets consume raw Jellyfin JSON/API DTOs directly.

Keep separate concepts for:

- Jellyfin API models;
- Jellyfinity domain models;
- presentation state;
- persistence models.

Avoid global folder dumping such as one giant `controllers/`, `models/`, `views/`, `repositories/` hierarchy.

Prefer feature-local code; extract shared modules when genuinely shared.

Do not prematurely build a plugin framework.

---

## Key Engineering Philosophy

- TDD where meaningful.
- Tests should focus on behavior/contracts, not coverage vanity.
- Use dependencies for labor-intensive infrastructure when justified.
- Do not add dependencies for trivial code.
- Document important architecture choices as concise ADRs.
- Repository history should look professional: focused branches, meaningful commits, PRs, CI, changelog, semantic releases.
- `main` should stay releasable.
- Prefer simple GitHub-flow-style branches such as `feature/*`, `fix/*`, `refactor/*`, `docs/*`, `chore/*`.
- Avoid enterprise process for its own sake.

---

## Initial Release Path

### v0.0.1
Repository/project foundation:
Flutter project, structure, docs, contribution rules, linting, tests, CI, license, release conventions.

### v0.0.2
Application architecture core:
bootstrap, state management, DI/composition, result/error model, logging, architecture ADRs.

### v0.0.3
Navigation/design system:
router, shell, design tokens, theme abstraction, loading/error/empty UI primitives.

### v0.0.4
Jellyfin transport:
HTTP layer, Jellyfin client identity, version validation, authenticated-capable requests, normalized errors, serialization.

### v0.0.5
Authentication/sessions:
server setup, login, secure token storage, saved servers/users, active profile, restore, logout/switching.

### v0.0.6
Persistence/cache:
local DB, migrations, metadata/artwork cache, preferences, local/remote repository conventions, large-library behavior.

### v0.0.7
Media domain:
Artist, Album, Track, Playlist, Movie, Series, Season, Episode, availability, progress; Jellyfin DTO → domain mapping.

### v0.0.8
Music library:
artists/albums/tracks, music navigation, search, artwork, pagination, caching, partial/offline states; must handle ~130k songs.

### v0.0.9
Audio playback:
audio engine, persistent queue, mini-player, Now Playing, background/system controls, gapless playback, queue restore.

### v0.1.0
First coherent usable music client:
connect → login → browse large music library → search → play → manage persistent queue → background playback with polished states.

---

## Important v0.1.0 Non-Goals

Do **not** expand v0.1.0 to include:

- full offline downloads;
- movies;
- TV;
- unified multi-server libraries;
- social sharing;
- collaborative playlists;
- full theme editor;
- plugins;
- desktop;
- Android TV;
- advanced recommendations.

Those are post-v0.1.0.

---

## Major Post-v0.1.0 Intent

Important later features:

- Spotify/Netflix-style integrated downloads for songs/albums/artists/playlists/movies/episodes/seasons/shows;
- robust movies and TV UX;
- integrated video playback;
- next episode, intro/credit skip;
- advanced music features: lyrics, synced lyrics, crossfade, ReplayGain/normalization;
- playlist curation;
- portable Jellyfinity share links that resolve media on another user's own server;
- collaborative playlists;
- modular/customizable Home;
- deep theme system;
- search scopes/context-aware search;
- recommendations/discovery;
- possible unified libraries across multiple Jellyfin servers in a major future version;
- Windows/Linux clients later;
- Android TV later;
- possible plugin system only if real demand justifies it.

---

## Product Inspiration

Useful interaction/design references include:

- Spotify;
- SoundCloud;
- Netflix;
- Discord.

Do not clone them.

Use them as quality/usability references.

---

## Critical Domain Concepts

Keep these separate:

- Server
- User
- Credential/token
- Session
- Saved profile/account
- Active profile

The queue is **Jellyfinity application state**, not merely state inside a playback package.

Downloads are **first-class local media**, not temporary cache files.

---

## Before Making a Major Technical Decision

Check:

1. Does it support Android and iOS well?
2. Does it scale to large libraries?
3. Is it testable?
4. Does it preserve offline/local-first requirements?
5. Does it avoid leaking Jellyfin transport details into UI/domain logic?
6. Is the dependency actively maintained and replaceable?
7. Does it fit the product philosophy?
8. Should the decision be recorded as an ADR?

For full rationale, read:

- `PHILOSOPHY.md`
- `ROADMAP.md`
- `OUTLOOK.md`
