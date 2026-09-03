# ADR-0009: Authentication, Sessions & Credential Storage

## Status

Accepted

## Context

`ROADMAP.md`'s v0.0.5 scope is the first complete real user journey —
add a server, validate it, log in, persist the session, restore it on
restart, switch profile, log out — and the first production feature that
touches secure storage, persistence, navigation, and account identity at
once. It also creates the session context every later media feature
depends on.

`CONTEXT.md` requires five concepts to stay distinct: **server**, **user**,
**credential/token**, **saved profile**, **active profile**. ADR-0008 left
two seams for exactly this milestone: `AuthTokenProvider` (transport asks
"is there a token?") and `JellyfinServerProbe.validate` (server
validation). ADR-0001 says `lib/domain/` gains content only when a feature
needs it — v0.0.5 is that point.

## Options Considered

### Where the session concepts live

1. **`lib/domain/session/`** (chosen) — the value objects
   (`JellyfinServer`, `JellyfinAccount`, `AuthSession`, `AuthenticatedUser`)
   and the contracts (`ServerRegistry`, `AccountStore`, `CredentialStore`,
   `JellyfinAuthenticator`) graduate straight into `lib/domain/`. The
   roadmap explicitly frames session context as the foundation for *every*
   later feature, so this is "a second feature genuinely needs it" the
   moment music browsing starts — extracting now avoids a churny move
   later and keeps the auth feature's presentation thin.
2. **`lib/features/auth/domain/`** — keep it feature-local until v0.0.7
   forces the move. Rejected: media repositories, playback, and the
   transport token provider all need "which server / which token" and none
   of them are the auth feature; the move is inevitable and the interim
   feature-local location would leak imports across features in the
   meantime.

### Secure token storage

**`flutter_secure_storage`** (chosen). `PHILOSOPHY.md` §14 names secure
credential storage as a take-a-dependency area. It wraps the iOS Keychain
and, on Android, Keystore-backed `EncryptedSharedPreferences`; it is
widely used and actively maintained. Wrapped behind the `CredentialStore`
contract so the dependency is replaceable and the rest of the app never
imports it. Hand-rolling platform channels for Keychain/Keystore was
rejected as exactly the reinvention §14 warns against.

### The saved-servers / profiles registry

The roadmap puts the real local database in **v0.0.6**, but v0.0.5 needs
somewhere durable for the (non-secret) list of saved servers and profiles
and the active-profile pointer. Options:

1. **A minimal JSON-file store behind the domain contracts** (chosen).
   `JsonStore` / `FileJsonStore` write one small JSON file per concern in
   the app-support directory (atomic write-and-rename; a corrupt file
   degrades to "empty", never a crash). `FileServerRegistry` and
   `FileAccountStore` implement the domain contracts on top. v0.0.6
   replaces *only these implementation classes* with database-backed ones
   — nothing above the contracts changes, and this ADR's `JsonStore` and
   its files are then deleted.
2. **`shared_preferences`** — another dependency for what a single JSON
   file does, and still interim.
3. **Everything (including the registry) in `flutter_secure_storage`** —
   misuses secure storage for non-secret data and is slower.
4. **Pull the v0.0.6 database forward** — breaks the roadmap's release
   boundaries for no v0.0.5 benefit.

### Login mechanism

**Username + password via `POST /Users/AuthenticateByName`** only. Quick
Connect is deferred (`OUTLOOK.md` §20, advanced onboarding). The first
multi-account UI is deliberately simple (roadmap: "the first UI can
remain simple").

## Decision

### Domain (`lib/domain/session/`)

- **`JellyfinServer`** — a saved server: local `id` (UUID), normalized
  `baseUrl`, display `name`, `reportedVersion`, optional Jellyfin
  `serverId`. No user, no token.
- **`JellyfinAccount`** — a saved profile: local `id` (UUID), the
  `serverId` it belongs to, the Jellyfin `userId`, and `username`. No
  token — the credential store is keyed by this `id`.
- **`AuthSession`** — the runtime join of an account, its server, and the
  access token; assembled at login / restore, never persisted as a unit.
  `toString` omits the token.
- **`AuthenticatedUser`** — the authenticator's output (Jellyfin user id,
  username, access token) before it becomes a saved account.
- Contracts, kept narrow (ADR-0001): **`ServerRegistry`**,
  **`AccountStore`** (+ the active-account pointer), **`CredentialStore`**,
  **`JellyfinAuthenticator`**.

### Infrastructure

- **`lib/infrastructure/persistence/`** — `JsonStore` + `FileJsonStore`
  (interim; see above), and `FileServerRegistry` / `FileAccountStore`.
  The store's directory is resolved lazily from `path_provider` so
  constructing it touches no platform channel (keeps
  `configureDependencies()` usable in plain unit tests).
- **`lib/infrastructure/secure/`** — `SecureCredentialStore` over
  `flutter_secure_storage` (Android `EncryptedSharedPreferences`; iOS
  Keychain, `first_unlock_this_device`, not iCloud-synced). Tokens are
  namespaced per account id.
- **`lib/infrastructure/jellyfin/auth/`** — `DioJellyfinAuthenticator`
  (`AuthenticateByName` over the shared `JellyfinHttpClient`, which gained
  a `postJson` surface) and the `AuthenticationResultDto` /
  `AuthenticatedUserDto` API DTOs (`json_serializable`, all-nullable, same
  rules as `PublicSystemInfoDto`). A 401 from this endpoint is remapped to
  "Incorrect username or password." The password is only ever in the POST
  body — `CorrelationInterceptor` logs method and path only.

### App (`lib/app/session/`)

- **`AuthSessionManager`** (`@lazySingleton`) — plain async logic (no
  Cubit) that joins the three stores and the authenticator: `restore`,
  `logIn`, `switchTo`, `logOut`, `invalidateCurrent`, `removeAccount`,
  `removeServer`. Mints local ids through a settable seam (like
  `JellyfinServerProbe.httpClientFactory`).
- **`SessionCubit`** (`@lazySingleton`) — rewritten from the v0.0.3 stub.
  Holds `SessionState` (`status` = `unknown` / `unauthenticated` /
  `authenticated`, plus the `AuthSession` and a `lastAccountId` for
  re-login prefill). Thin orchestrator over the manager; the router seam
  (`SessionStatus`, `refreshListenable`) is unchanged, as ADR-0006
  anticipated.
- **`SessionAuthTokenProvider`** (`@LazySingleton(as: AuthTokenProvider)`)
  — the real `AuthTokenProvider`, returning `AuthSessionManager.currentToken`
  (an in-memory field, so no per-request storage hit). Replaces
  `NoAuthTokenProvider` in DI; `NoAuthTokenProvider` stays for token-less
  requests (probe, login) and tests.

### Session restore

On startup `bootstrap` calls `SessionCubit.restore()` **without
awaiting**: the app renders the splash (`SessionStatus.unknown`) and moves
to the shell or onboarding once storage is read. Restore does **no
network call** — a stored token is trusted until a request actually comes
back `UnauthorizedFailure`, at which point `SessionCubit.handleUnauthorized`
drops the session (keeping the saved profile) and the router returns the
user to sign-in. This is what lets the app launch straight into a usable
shell when the last server is currently offline (a roadmap requirement).
`handleUnauthorized` is wired and tested but not yet *invoked* anywhere:
nothing in v0.0.5 makes an authenticated request. The v0.0.7 media
repositories are where a session-scoped authenticated client (and the
interceptor that calls `handleUnauthorized` on a 401) get built — the
same "leave the seam, fill it when a feature needs it" approach ADR-0008
took with `AuthTokenProvider`.

### Navigation

`RoutePaths.onboarding` = `{welcome, connect, signIn}`. The redirect: an
unauthenticated user is allowed anywhere in that set and bounced to
`/welcome` otherwise; an authenticated user is bounced off `/splash` and
`/welcome` to `/home` and allowed everywhere else (so `/accounts` and the
add-another-account flow work while signed in). The validated
`JellyfinServerInfo` is passed to the login route as `extra`.

### Device identity — explicitly deferred

`JellyfinClientIdentity` still uses an ephemeral per-launch device id
(ADR-0008). Jellyfin access tokens stay valid across requests regardless
of the device-id header, so session restore works; the only cost is
server-side "device" list clutter, which v0.0.6 cleans up when it
persists a stable id (only `JellyfinTransportModule.clientIdentity()`
changes). The roadmap does not list device identity under v0.0.5.

## Tests

TDD on the roadmap's listed cases, all without a network or a real
platform: in-memory fakes for the three stores + a scripted
`FakeJellyfinAuthenticator` (`test/support/session_fakes.dart`);
`FileJsonStore` exercised against a temp directory; the authenticator
against the existing `FakeDioAdapter`. Covered: successful auth, invalid
credentials, unsupported version, token/DTO mapping, session persistence
and restore across a simulated restart, restore-without-network
(server-offline-at-startup), switching, logout keeping the profile,
server removal cascading to profiles and tokens, and the JSON store's
corrupt-file degradation.

## Consequences

- `lib/domain/` now has real content; later features consume
  `JellyfinServer` / `AuthSession` without importing infrastructure.
- Three new dependencies (`flutter_secure_storage`, `path_provider`,
  `uuid`), each behind a contract or confined to one file.
- The interim JSON store is deliberate debt with a clear repayment point
  (v0.0.6) and a contract boundary that makes the swap local.
  > **Repaid by ADR-0010 (v0.0.6).** `JsonStore` / `FileJsonStore` and the
  > `File*` store implementations are deleted; `DriftServerRegistry` /
  > `DriftAccountStore` implement the same contracts over SQLite, and a
  > one-time `LegacyJsonImporter` moves any existing `servers.json` /
  > `accounts.json` into the database. Nothing above the contracts changed.
- `bootstrap` now calls `WidgetsFlutterBinding.ensureInitialized()` (it
  reaches platform storage during restore) — no test drives `bootstrap`,
  so this is not observable in the suite.
- The re-auth-on-401 path is designed and unit-tested but not wired,
  pending the first authenticated request in v0.0.7.
