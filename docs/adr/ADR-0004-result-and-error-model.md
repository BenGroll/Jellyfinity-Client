# ADR-0004: Result and Error Model

## Status

Accepted

## Context

`ROADMAP.md`'s v0.0.2 scope requires a common representation for
successful results, expected failures, unexpected failures, recoverable
failures, unavailable data, and partial results, and requires that raw
transport exceptions never reach UI code directly. `CONTEXT.md`'s first
product rule ("never leave the user guessing") and its partial-success
example (showing 11 usable tracks of 12, with the unavailable one marked)
depend on this being modeled consistently everywhere, not per feature.

## Options Considered

1. **A hand-written `Result`/`Failure` model** (chosen) — a small sealed
   `Result<T>` (`Ok`/`Err`) plus a sealed `Failure` hierarchy, written
   directly in `lib/core/result/`.
2. **A third-party Result package** (e.g. `result_dart`, `fpdart`'s
   `Either`) — would provide a similar shape with less code to maintain,
   but the type itself is small and stable enough that
   `PHILOSOPHY.md`'s "do not add dependencies for trivial code" applies
   directly; a hand-written version can also be shaped exactly around
   this project's specific failure categories and `Partial` type instead
   of adapting a generic library's vocabulary.
3. **Throwing typed exceptions, caught at layer boundaries** — rejected:
   harder to enforce that every call site handles failure (nothing at the
   type level forces it, unlike a sealed `Result` requiring exhaustive
   handling), and does not naturally represent "success, but partial."

## Decision

Jellyfinity uses a hand-written `Result`/`Failure`/`Partial` model in
[`lib/core/result/`](../../lib/core/result/):

- **`Result<T>`** (`result.dart`) — a sealed type with `Ok<T>` (success,
  carrying a value) and `Err<T>` (failure, carrying a `Failure`).
  Provides `.when(ok:, err:)` for exhaustive handling, `.map()`, and
  `isOk`/`isErr`/`valueOrNull`/`failureOrNull` for lighter-weight call
  sites.
- **`Failure`** (`failure.dart`) — a sealed base with three subtypes
  covering the roadmap's required categories:
  - `RecoverableFailure` — the user can typically retry (e.g. a timed-out
    request).
  - `UnavailableFailure` — the requested data is currently unavailable,
    but this is an expected/understood condition (e.g. server
    unreachable, item removed).
  - `UnexpectedFailure` — an unanticipated failure, typically wrapping an
    uncaught exception from infrastructure code.

  > **Extended by ADR-0008 (v0.0.4).** The transport layer added two more
  > subtypes to this sealed hierarchy — `UnauthorizedFailure` (HTTP
  > 401/403) and `UnsupportedServerFailure` (reached, but not a supported
  > Jellyfin server) — because the v0.0.4 roadmap error list distinguishes
  > them and v0.0.5's re-login logic keys off the auth one. This
  > supersedes the "an auth-specific failure in v0.0.5" remark in the
  > Consequences below. The base set is still kept deliberately small.

  Every `Failure` carries a presentable `message`, plus an optional
  `cause`/`stackTrace` for diagnostics. `message` must never contain
  credentials, tokens, or other sensitive data (same rule as logging;
  see ADR-0004's companion logging convention below and `Logger`'s
  documentation).
- **`Partial<T>`** (`partial.dart`) — not a failure. Wraps a successful
  `Result` whose value is incomplete: `available` (the items that did
  resolve) and `unavailable` (`UnavailableItem`s — an id and a
  presentable reason for each item that didn't). This is the
  general-purpose vehicle for "partial success beats total failure": a
  repository call that would otherwise need to choose between "fail
  everything" and "silently drop the missing item" instead returns
  `Ok(Partial(available: [...], unavailable: [...]))`, and presentation
  code decides how to show the gap.

Infrastructure code (starting with transport in v0.0.4) is responsible
for catching raw exceptions and translating them into an appropriate
`Failure`, so domain and presentation code only ever see `Result`/
`Failure`/`Partial`, never a raw `Exception`/`Error` from a
package/platform API.

## Consequences

- Every fallible operation's signature (`Result<T>`) makes success and
  failure explicit at the type level; `when()` forces callers to handle
  both, which directly supports "never leave the user guessing."
- `Partial<T>` gives every feature the same shape for partial success
  instead of each one inventing its own (a flag plus a separately-tracked
  error list, a sentinel value, etc.), which keeps partial-state UI
  patterns consistent across music, and later movies/TV.
- Three `Failure` subtypes are deliberately few; feature-specific failure
  detail belongs in `message`/`cause`, or in a feature adding its own
  `Failure` subtype later if a genuinely new category emerges (e.g. an
  auth-specific failure in v0.0.5) — not by growing this base set
  speculatively now.
- Because this is hand-written rather than a library, its shape can
  evolve with the project's actual needs, at the cost of Jellyfinity
  owning its maintenance (acceptable given its small size).
