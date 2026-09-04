# ADR-0010: Persistence, Cache & Local Data Foundation

## Status

Accepted

## Context

`ROADMAP.md`'s v0.0.6 is the local-data foundation every later media
feature depends on. Jellyfinity must never degrade to
`Widget → Jellyfin API → JSON → Widget`: fast startup, offline-tolerant
presentation, partial availability, a persistent queue, and a ~130k-track
library all require local persistence to be a first-class concern before
the music UI is built on network-only data.

This milestone also repays two explicit debts:

- ADR-0009's interim `JsonStore` / `FileJsonStore` — one JSON file per
  concern for the saved servers and profiles — was accepted only "until
  the v0.0.6 database", behind the `ServerRegistry` / `AccountStore`
  contracts so the swap stays local.
- ADR-0008 (reaffirmed by ADR-0009) deferred a **stable device id** to
  "once the persistence layer exists": until now every launch reported a
  fresh `DeviceId`, cluttering a server's device list.

Scope is foundation only. No media domain entities (v0.0.7), no music
browsing (v0.0.8), no real downloads (post-v0.1.0).

## Options Considered

### Local database technology

1. **SQLite via `drift`** (chosen). Relational SQL with real indexes and
   query planning — the right shape for a 130k-row library with
   pagination and server-side-style filtering. First-class, ordered
   migrations (`schemaVersion` + `MigrationStrategy`). Compile-time
   verified queries and generated row/companion types, so mapping code is
   not hand-written. `NativeDatabase.memory()` makes every test
   hermetic — no platform channel, no file. Very actively maintained,
   ships its own bundled SQLite (`sqlite3` 3.x), Android + iOS support is
   mature. Wrapped behind the existing domain contracts, so it is
   replaceable.
2. **Isar**. Fastest raw benchmarks and an ergonomic Dart query API, but
   v3 maintenance has been intermittent and v4 is an unfinished rewrite —
   it fails the roadmap's "dependency longevity" test for a foundational
   choice. Migrations are also less explicit than SQL.
3. **`sqflite` + a hand-rolled mapping/migration layer**. Minimal
   dependency surface, but re-implements row↔object mapping, query
   building and migration plumbing by hand — precisely the
   "labor-intensive infrastructure" `PHILOSOPHY.md` §14 says to take a
   dependency for.
4. **Hive / `shared_preferences`**. Not suited to a large relational
   dataset; `shared_preferences` was already rejected in ADR-0009 for the
   registry.

### `drift` / `drift_dev` version

Pinned to **2.34.0** (both packages, matched). Newer `drift_dev`
(≥ 2.34.6) pulls an `analyzer` / `test_api` combination that conflicts
with the Flutter SDK's bundled `flutter_test`; `drift_flutter` ≥ 0.3.0
also depends on the transitional `sqlite3_flutter_libs 0.6.0+eol` shim
(the native libraries now ship inside `sqlite3` 3.x). Revisit both on the
next Flutter upgrade.

### Where the database-backed stores live

`lib/infrastructure/persistence/` — `DriftServerRegistry` and
`DriftAccountStore` implement the **unchanged** `lib/domain/session/`
contracts, exactly as ADR-0009 planned. Nothing above the contracts moved.
`JsonStore`, `FileJsonStore`, `FileServerRegistry`, `FileAccountStore`,
`PersistenceModule` and their tests are deleted.

### Migrating the existing JSON data

A one-time **`LegacyJsonImporter`**, run from `bootstrap` before session
restore. If the database already holds servers it is a no-op (fresh
install, or a prior import). Otherwise it reads `servers.json` /
`accounts.json` from the app-support directory (where `FileJsonStore`
wrote them), imports the rows and the active-account pointer in a
transaction, and renames the sources to `*.migrated` rather than deleting
them, so a botched migration is recoverable. Any failure is logged and
swallowed — a bad import must never block startup.

### Preferences / small key-value state

A single typed **`KeyValueStore`** over one `key_value_entries` table,
shared by: user preferences, the persisted device id (`device.id`), and
the active-account pointer (`session.active_account_id`). This is the one
primitive those concerns share — deliberately not a settings *framework*.
Secrets never go here (that is `CredentialStore` / secure storage);
anything large or relational gets its own table.

### Device identity

`DeviceIdentityStore` (`PersistentDeviceIdentityStore`) generates a UUID
once, stores it in `KeyValueStore`, and returns the same value forever
after. `JellyfinClientIdentity` is now produced by an `@preResolve` async
module provider that awaits it, so `configureDependencies()` reads (or,
first launch only, creates) the id before the DI graph is handed out.
This is the first thing that makes `configureDependencies()` touch the
database; tests that call it install a temp-directory `path_provider`
fake (`test/support/fake_path_provider.dart`). The DB connection itself is
still lazy (`drift_flutter`'s `driftDatabase` resolves its path on first
query), so merely constructing the graph hits no channel.

## Decision

### Schema (v1) — `lib/infrastructure/persistence/database/`

- **`saved_servers`** — `id` (PK, local UUID), `base_url`, `name`,
  `reported_version` (default `''`), `server_id` (nullable), `added_at`
  (µs-since-epoch insertion marker). Index on `base_url`.
- **`saved_accounts`** — `id` (PK, local UUID), `server_id`, `user_id`,
  `username`, `added_at`. Index on `server_id`. **No** DB foreign key:
  `AuthSessionManager` already orchestrates cascading removal (it must
  also delete the token from secure storage, which the DB cannot see), so
  a DB cascade would only duplicate that.
- **`key_value_entries`** — `key` (PK), `value` (text), `updated_at`.
- `PRAGMA foreign_keys = ON` in `beforeOpen`.

`all()` / `forServer()` order by `added_at`, preserving the "insertion
order" the contracts promise; `save()` keeps the original `added_at` on
update, so editing a row does not reorder the list.

### Migration policy

`schemaVersion` starts at **1**. Every schema change:

1. bumps `schemaVersion` by one;
2. adds an ordered step to `MigrationStrategy.onUpgrade`
   (`if (from < N) { ... }`) — the database is **never** dropped on
   upgrade;
3. regenerates the snapshot: `dart run drift_dev schema dump
   lib/infrastructure/persistence/database/AppDatabase.dart drift_schemas/`;
4. adds a migration test that steps a v(N-1) database up to vN.

The committed `drift_schemas/drift_schema_v1.json` is the reference for
what shipped. `app_database_test.dart` asserts the live schema (version,
tables, indexes, pragma) and that reopening an existing file preserves
data.

### Cache semantics (definitions; concrete use lands with the media
features)

Five distinct categories, to be honoured by every repository from v0.0.7
on:

| Category | Lifetime | Eviction | Example |
|---|---|---|---|
| **Persisted metadata** | until refreshed from the server or the row is removed | never automatic | an album's title/track list |
| **Temporary cache** | best-effort | bounded (size / age), safe to drop any time | a search-results page |
| **Artwork cache** | best-effort, on disk | bounded disk + memory, LRU | poster / cover images |
| **User-authored local state** | until the user changes it | never dropped silently | the queue, preferences, "only on device" marks |
| **Downloadable media state** | first-class local media | only on explicit removal; survives server deletion | a downloaded album (post-v0.1.0) |

### Repository source strategy (convention; no code yet)

Media repositories from v0.0.7 combine a local and a remote source behind
one domain contract. The UI never learns which answered. The convention:

- **read-through, local-first** — serve the local copy immediately if
  present, kick off a remote refresh, update the local copy, surface the
  update through the repository's stream;
- represent "we have *something* but it may be stale / incomplete" with
  the ADR-0004 `Result` / `Partial` model, not a bare failure;
- when the server is unreachable, previously-persisted metadata stays
  browsable (a roadmap requirement) — an `UnavailableFailure` is only for
  data never fetched.

No base class is introduced now: with no consumer, the abstraction would
be guesswork. It is written once, against a real second caller, in
v0.0.7/v0.0.8.

### Artwork cache

Behaviour and invalidation strategy are specified above (bounded disk +
memory, LRU, keyed by Jellyfin image tag so a changed tag is a natural
cache-bust). The concrete disk cache is **deferred to v0.0.8**, when the
first widget actually renders artwork — per the v0.0.6 decision to design
the strategy now and implement at the point of use. No image dependency
is added in this milestone.

## Tests

All hermetic (`NativeDatabase.memory()` or a temp file; no network, no
platform channel except the `path_provider` fake):

- `app_database_test` — schema version, tables, indexes, FK pragma, and
  file-reopen data preservation.
- `drift_server_registry_test` / `drift_account_store_test` — the full
  contracts: CRUD, insertion order, `byBaseUrl` / `byServerAndUser`,
  upsert-in-place, the active pointer (round-trip, validation, cleared on
  removal of the active account, untouched otherwise).
- `key_value_store_test` — typed round-trips, single-row upsert, removal.
- `device_identity_store_test` — generate-once, persistence across
  instances, independence between databases.
- `legacy_json_importer_test` — import (rows + active pointer + file
  retirement), skip when the DB already has data, no-op with no files,
  bad active pointer ignored, corrupt file survived without partial
  import.
- `scale_test` (`@Tags(['scale'])`) — 130k `key_value_entries` rows via a
  batched transaction, an indexed point lookup that stays sub-50ms, and
  full offset pagination that never materialises the whole set. A
  stand-in until real media tables exist; media-scale query tests arrive
  in v0.0.8.

## Consequences

- `lib/infrastructure/persistence/` is now Drift-based; the interim JSON
  store and its tests are gone. `AppDatabase` is the single local store
  every later feature extends with tables.
- `configureDependencies()` now reads the database (for the device id).
  Its "no platform channel" property was always scoped to the *interim*
  layer; the DB connection stays lazy, and one test helper covers the
  gap.
- New dependencies: `drift`, `drift_flutter` (main), `drift_dev` (dev),
  both drift packages version-pinned. `sqlite3` 3.x and the
  `sqlite3_flutter_libs` / `sqlcipher_flutter_libs` `+eol` shims arrive
  transitively via `drift_flutter`.
- A stable `DeviceId` is now reported to servers — ADR-0008's and
  ADR-0009's deferral is closed. Only
  `JellyfinTransportModule.clientIdentity` changed.
- Cache semantics and the repository-source convention are documented but
  uncoded; v0.0.7 is expected to implement them against a real caller and
  may refine this ADR.
- The `LegacyJsonImporter` is throwaway code with a definite end: once
  there is no realistic install still holding a v0.0.5 `servers.json`, it
  and this note can be removed.
