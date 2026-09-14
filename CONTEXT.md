# Jellyfinity context

Stable constraints that commonly affect implementation. Read rationale only
when a concrete decision needs it: `PHILOSOPHY.md`; future ideas:
`OUTLOOK.md`.
Minimum supported server: Jellyfin 10.11.6.

## Product invariants

- Make state explicit: distinguish loading, empty, partial, offline, cached,
  unavailable, unauthorized, and failed. Preserve usable partial results.
- Music is the initial focus; movies and TV remain future first-class media.
- Offline is an availability state. Work-offline may show the cached library or
  downloads only; downloaded media is durable first-class local media.
- No ads, paid tiers, unnecessary telemetry, or unnecessary cloud dependency.
- Support roughly 130k songs, 500 movies, and 4k episodes with pagination,
  lazy or virtualized lists, indexed storage, and bounded caches.

## Architecture invariants

```text
UI -> presentation -> domain contracts <- infrastructure
```

- Keep feature-local code and distinct transport, domain, presentation, and
  persistence models. Widgets never consume raw Jellyfin DTOs or exceptions.
- Keep `Server`, `User`, credentials, sessions, saved accounts, and the
  active account distinct.
- Playback queue state belongs to Jellyfinity application/domain state, not an
  audio package.
- Avoid speculative abstractions and plugins. Dependencies must provide
  substantial, replaceable infrastructure value.

## Engineering invariants

- Test behavior and contracts; use TDD where meaningful.
- Every feature supports Android and Windows with equivalent behavior, including
  relevant touch, background-media, pointer, keyboard, windowed-layout, and
  media-session interactions. Preserve iOS unless scope changes.
- Normalize failures and preserve partial state. Record durable architectural
  choices as concise ADRs.
- Before major decisions, check platform support, large-library behavior,
  testability, offline effects, dependency direction, and replaceability.
