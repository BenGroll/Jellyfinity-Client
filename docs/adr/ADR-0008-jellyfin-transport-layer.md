# ADR-0008: Jellyfin Transport Layer

## Status

Accepted

## Context

`ROADMAP.md`'s v0.0.4 scope requires the reusable networking foundation
every later Jellyfin-backed feature depends on: an HTTP client abstraction
(base URL, request construction, response parsing, timeouts, cancellation,
bounded retry, test doubles), centralized Jellyfin client identity, server
version validation against **Jellyfin 10.11.6**, authentication-aware
requests *without* the full login flow, normalization of transport
failures into the ADR-0004 `Failure` model, narrowly-scoped middleware, and
a serialization approach that keeps API DTOs separate from domain models.

Networking is exactly the kind of "labor-intensive infrastructure"
`PHILOSOPHY.md` §14 says to take a dependency for. The open question was
*how much* to take: a full generated/third-party Jellyfin client, or a
thin hand-rolled one over a general HTTP library.

## Options Considered

### Jellyfin API client

1. **Hand-rolled thin client** (chosen) — Jellyfinity writes its own
   `JellyfinHttpClient` plus only the DTOs and endpoints each milestone
   actually uses. Matches the roadmap's repeated "implement only what
   serves known behavior", keeps the API surface small and fully
   understood, and lets error/identity handling be shaped exactly to
   ADR-0004. Cost: more code is written over time as endpoints are needed.
2. **Client generated from Jellyfin's OpenAPI spec** — broad coverage for
   free, but a large generated surface to vendor and keep in the repo, and
   it still has to be wrapped so DTOs and its exception types don't leak
   past infrastructure (ADR-0001). The coverage is mostly of endpoints
   Jellyfinity will never call.
3. **A third-party pub package** (`jellyfin_dart`, `dart_jellyfin`, …) —
   least code now, but makes a core layer depend on an external package's
   maintenance cadence, versioning, and its own identity/error decisions,
   and it would still need wrapping. `PHILOSOPHY.md` §14's replaceability
   and API-stability criteria weigh against it for something this central.

### HTTP library

**`dio`** (chosen) over `package:http`. `dio` provides interceptors,
per-request timeouts, `CancelToken`, and a pluggable `HttpClientAdapter`
(which is how tests inject a fake transport) as first-class concepts —
exactly the v0.0.4 checklist. `package:http` is smaller but would have us
re-implement the interceptor pipeline, cancellation, and retry by hand,
which is the reinvention §14 warns against. `dio` is widely used and
actively maintained.

### DTO serialization

**`json_serializable`** (chosen) over hand-written `fromJson` and over
`freezed`. `build_runner` is already in the project for `injectable`, so
`json_serializable` adds a well-trodden generator and no new runtime
dependency of note. Hand-written parsing was judged to add up to a lot of
error-prone boilerplate across many DTOs; `freezed` adds ergonomics (unions,
`copyWith`) that transport DTOs — plain, immutable, read-only shapes — do
not need. DTOs are annotated `createToJson: false` (responses only, for
now) and every field is nullable so one missing field degrades a single
check instead of failing the whole parse.

## Decision

Everything lives under **`lib/infrastructure/jellyfin/`**, exported via
`jellyfin.dart`. No domain contracts are introduced yet — per ADR-0001
`lib/domain/` gains content only when a *feature* needs it (v0.0.5), so
v0.0.4 is purely an infrastructure toolkit.

- **`JellyfinHttpClient`** (`http/`) wraps one `Dio` bound to a single
  server's base URL (timeouts, `ResponseType.json`). Its request surface
  (`getJson<T>`) returns `Result<T>` and catches everything — a
  `DioException` never escapes it. It is created *per server* (not a DI
  singleton); `JellyfinServerProbe` builds one for a probe, and v0.0.5
  will build a session-scoped one after login. Tests pass their own `Dio`
  with a fake `HttpClientAdapter`.

- **Client identity** (`identity/`). `JellyfinClientIdentity` is the one
  place the `Authorization: MediaBrowser Client=…, Version=…, DeviceId=…,
  Device=…, Token=…` header value is constructed. Jellyfin folds app
  identity *and* the session token into this single header, so identity
  and auth are one transport concern, not two. It is a DI singleton,
  registered via `JellyfinTransportModule` because building it needs a
  device id whose source changes across milestones (an ephemeral
  per-launch id now; a persisted stable id after v0.0.6 — only the module
  method changes).

- **Authentication-aware, pre-login.** `AuthTokenProvider` is the seam to
  v0.0.5: the transport only asks "is there a token?". `NoAuthTokenProvider`
  (always `null`) is the v0.0.4 implementation; v0.0.5 swaps in one backed
  by secure storage and the active session without transport code changing.

- **Version policy** (`server/`). `ServerVersion` parses Jellyfin's dotted
  version (3 or 4 parts, ignoring any suffix). `MinimumServerVersionPolicy`
  holds the single floor value (`10.11.6`); raising or, per `OUTLOOK.md`
  §21, deliberately lowering it later is a one-line change.

- **Server validation.** `JellyfinServerProbe.validate(url)` normalizes the
  URL (`JellyfinServerUrl` — scheme defaulting, trailing-slash trimming,
  reverse-proxy base paths preserved), calls the unauthenticated
  `GET /System/Info/Public`, confirms `ProductName` contains "jellyfin"
  (rejecting Emby and unrelated services), parses and policy-checks the
  version, and returns `Result<JellyfinServerInfo>`. v0.0.5's "add a
  server" flow calls straight into this.

- **Error normalization.** `TransportErrorMapper` is the single funnel
  from raw errors to `Failure`: timeouts / connection errors / cancellation
  → `RecoverableFailure`; bad TLS certificate → `UnavailableFailure`;
  HTTP 401/403 → `UnauthorizedFailure`; 404 → `UnavailableFailure`; 5xx →
  `RecoverableFailure`; malformed/unreadable body → `UnexpectedFailure`;
  "reached, but not a supported Jellyfin server" → `UnsupportedServerFailure`.
  `UnauthorizedFailure` and `UnsupportedServerFailure` are **new
  `Failure` subtypes** added to `lib/core/result/failure.dart` (see the
  note added to ADR-0004): the roadmap's v0.0.4 error list explicitly
  distinguishes "unauthorized"/"forbidden" and "unsupported server
  version", and v0.0.5's re-login logic keys off the auth one.

- **Middleware** (`http/jellyfin_interceptors.dart`), kept to genuinely
  cross-cutting transport concerns only:
  - `JellyfinAuthorizationInterceptor` — the identity/token header on
    every request.
  - `CorrelationInterceptor` — a short per-request id, logged with method
    and path only at `debug` level (never headers or query strings, per
    `Logger`'s privacy rule), so a failing request can be followed.
  - `RetryInterceptor` — bounded (default 2), linear backoff, **GET/HEAD
    only**, and only for connection/timeout errors — never a request that
    got an HTTP response, never a write. Anything smarter belongs in a
    repository, not here; repository caching / offline sync must not hide
    in HTTP middleware.

## Tests

Deterministic, no live server: a hand-written `FakeDioAdapter`
(`test/support/`) implements `dio`'s `HttpClientAdapter` and answers from a
per-test handler, so URL normalization, version policy, every error
mapping, the identity header, DTO parsing (including missing and
wrongly-typed fields), retry behaviour, and the full `validate` flow
(happy path, old version, non-Jellyfin, 401, connection failure, malformed
body, bad address) are all covered without a network or a new mocking
dependency.

## Consequences

- Later features get one HTTP entry point that already returns `Result` —
  no feature re-solves timeouts, identity, retry, or error translation.
- The API surface grows endpoint-by-endpoint as milestones need it, which
  keeps it small and fully understood, at the cost of writing each DTO
  (mitigated by `json_serializable`).
- `dio` is a dependency in a core layer; its adapter seam keeps it
  testable and its major-version churn is the main upgrade risk to watch.
- The `Failure` hierarchy grew by two subtypes; the exhaustive `switch`es
  in `lib/design/` were updated in step, which is the type system doing
  its job.
- `JellyfinHttpClient` is deliberately not a DI singleton — v0.0.5 owns
  the decision of how a session-scoped, authenticated client is built and
  provided.
