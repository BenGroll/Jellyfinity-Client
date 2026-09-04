# Jellyfinity Roadmap

## Scope of This Roadmap

This document defines the development path from **v0.0.1** through **v0.1.0**.

The `0.0.x` series consists of real architectural increments, not disposable experiments.

Every release should:

- leave the repository in a coherent state;
- compile;
- pass automated checks;
- have a clear purpose;
- introduce production-intended foundations;
- be independently understandable by a future contributor or development agent.

The objective is to build toward one complete first vertical slice:

> **v0.1.0: a credible day-to-day Jellyfin music client for Android and iOS.**

The implementation should not prematurely build every future feature, but architectural decisions must respect the known long-term requirements documented in `PHILOSOPHY.md` and `OUTLOOK.md`.

---

# v0.0.1 — Repository & Project Foundation

## Goal

Create a professional, reproducible Flutter repository with a clear project structure and contribution workflow.

The application itself may do little more than launch and display a basic Jellyfinity shell.

## Why This Is a Separate Release

The repository structure and development workflow are part of Jellyfinity's deliverable.

Before feature code exists, contributors and agents should already know:

- how to run the project;
- how to test it;
- where documentation belongs;
- how changes are contributed;
- how releases are represented;
- how architectural decisions are recorded.

This provides a stable base for every later release.

## Required Work

### Flutter Project

- initialize the Flutter project;
- configure Android;
- configure iOS;
- define the supported Dart/Flutter version strategy;
- make the app compile and launch on supported development targets;
- set the package/application naming conventions;
- add basic application metadata.

### Repository Structure

Establish the intended high-level structure.

Do not create large numbers of empty speculative directories.

Document the intended architecture even where a module does not yet exist.

Expected areas include:

```text
lib/
  app/
  core/
  design/
  domain/
  features/
  infrastructure/
```

Feature-oriented organization should be preferred within `features/`.

### Documentation

Create and maintain:

- `README.md`;
- `PHILOSOPHY.md`;
- `ROADMAP.md`;
- `OUTLOOK.md`;
- `CONTEXT.md`;
- `CONTRIBUTING.md`;
- `CHANGELOG.md`;
- `docs/adr/`;
- architecture documentation entry point.

### Engineering Rules

Define:

- branch naming conventions;
- commit conventions;
- pull request workflow;
- merge policy;
- semantic versioning expectations;
- changelog expectations;
- issue conventions.

Recommended initial branch model:

```text
main
 ├── feature/*
 ├── fix/*
 ├── refactor/*
 ├── docs/*
 └── chore/*
```

`main` should remain releasable.

### Static Quality

Configure:

- Dart formatting;
- linting;
- static analysis;
- basic test execution.

### CI

Add CI that verifies at minimum:

- formatting;
- analysis;
- tests;
- build sanity where practical.

### Licensing

Choose and add the project's open-source license.

The exact license should be an explicit project decision rather than an accidental default.

## Definition of Done

`v0.0.1` is complete when a new contributor can:

1. clone the repository;
2. follow the documented setup;
3. launch Jellyfinity;
4. run automated tests;
5. understand the high-level repository structure;
6. understand how to contribute;
7. see CI pass on the release commit.

---

# v0.0.2 — Application Architecture Core

## Goal

Establish the architectural primitives used by production features.

## Why This Is a Separate Release

Authentication, persistence, media repositories, playback, and UI modules should not invent their own state, error, dependency, and lifecycle patterns independently.

This release creates a common vocabulary before infrastructure-heavy features begin.

The goal is consistency, not a custom framework.

## Required Work

### Architecture

Formalize the intended dependency direction:

```text
UI
 ↓
Presentation
 ↓
Domain / Repository Contracts
 ↑
Infrastructure Implementations
```

Decide and document:

- feature-first organization;
- domain boundaries;
- infrastructure boundaries;
- how shared modules graduate out of individual features.

Create **ADR-0001** for the core architecture style.

### Application Bootstrap

Implement a clear application bootstrap process that can later initialize:

- configuration;
- logging;
- persistence;
- authentication/session state;
- dependency composition.

Keep startup testable.

### State Management

Select the primary Flutter state-management approach.

Evaluate it for:

- testability;
- async state representation;
- lifecycle behavior;
- contributor ergonomics;
- scalability;
- dependency cost.

Record the choice in an ADR.

### Dependency Composition

Select and implement the dependency injection/composition strategy.

Avoid hidden global state where practical.

The application should have a clear composition root.

### Result and Error Model

Define common representations for:

- successful results;
- expected failures;
- unexpected failures;
- recoverable failures;
- unavailable data;
- partial results where appropriate.

Do not expose raw transport exceptions directly to UI features.

### Logging

Add a logging abstraction suitable for development and production.

Logging must respect the privacy philosophy.

Sensitive credentials and tokens must never be logged.

### Configuration

Define environment/configuration conventions without introducing unnecessary build complexity.

## Tests

Add tests that prove the architectural primitives can be used without relying on production feature code.

Do not create a permanent fake product feature merely to demonstrate architecture.

## Definition of Done

`v0.0.2` is complete when future features can rely on documented, tested conventions for:

- state;
- dependencies;
- errors/results;
- bootstrap;
- logging;
- module boundaries.

---

# v0.0.3 — Navigation & Design System

## Goal

Create the visual and navigational foundation that all later screens use.

## Why This Is a Separate Release

Jellyfinity's design philosophy requires consistent loading, error, empty, navigation, and interaction behavior.

If every feature creates these independently, the application will immediately lose the coherence it is intended to provide.

## Required Work

### Routing

Select and configure the routing/navigation solution.

Support at minimum:

- application root;
- authenticated versus unauthenticated navigation;
- nested navigation where needed;
- future deep-link support;
- future tab-based navigation.

Record the routing decision in an ADR.

### Navigation Shell

Create the initial application shell.

The final primary navigation may evolve, but the architecture should support eventual sections such as:

- Home;
- Music;
- Movies;
- Shows;
- Library.

Do not fully implement empty future sections merely to populate navigation.

### Design Tokens

Create semantic tokens for concepts such as:

- colors;
- surfaces;
- text roles;
- spacing;
- radii;
- typography;
- elevation where applicable;
- animation durations where appropriate.

Avoid hard-coded visual constants throughout feature widgets.

### Theme Model

Create the first theme abstraction so future extensive customization does not require replacing the whole visual architecture.

Initial customization may be minimal.

The important requirement is that widgets consume semantic theme values.

### Shared UX Primitives

Create reusable patterns for:

- loading skeletons;
- empty states;
- error states;
- retry actions;
- disabled/unavailable content;
- standard page structure;
- consistent interaction feedback.

### Platform Behavior

Establish conventions for respecting Android/iOS behavior where relevant.

## Tests

Add widget tests for the major shared visual states and navigation shell behavior.

## Definition of Done

`v0.0.3` is complete when later features can be built without inventing their own:

- navigation conventions;
- theme access;
- loading visuals;
- empty-state patterns;
- error-state presentation.

---

# v0.0.4 — Jellyfin Transport Layer

## Goal

Create the reusable networking and Jellyfin API transport foundation.

## Why This Is a Separate Release

Authentication and media repositories require dependable communication with Jellyfin.

Networking concerns should be solved once and should not be embedded directly into screens or feature controllers.

## Required Work

### HTTP Transport

Implement or integrate the HTTP client abstraction.

Support:

- base server URL handling;
- request construction;
- response parsing;
- timeouts;
- cancellation where useful;
- appropriate retry policy;
- test doubles/fakes.

### Jellyfin Client Identity

Implement the required Jellyfin client/device headers and identifiers.

Keep client identity construction centralized.

### Version Validation

Support server validation against the current minimum supported version:

> **Jellyfin 10.11.6**

The version policy should be easy to update later.

### Authentication-Aware Requests

Prepare transport support for authenticated requests without requiring the full login flow yet.

### Error Normalization

Translate networking and server failures into Jellyfinity's common error model.

Examples include:

- DNS/host failure;
- timeout;
- connection refused;
- TLS/certificate failure;
- unauthorized;
- forbidden;
- not found;
- malformed server response;
- unsupported server version.

Raw exceptions should not escape into normal presentation code.

### Middleware / Interceptors

Introduce middleware only for clearly cross-cutting transport concerns.

Possible examples:

- authentication headers;
- client/device headers;
- request correlation/debug tracing;
- carefully bounded retry behavior.

Do not hide repository caching or offline synchronization inside HTTP middleware.

### Serialization

Define how Jellyfin API DTOs are decoded and tested.

Keep API DTOs separate from Jellyfinity domain models.

## Tests

Use deterministic tests with fake/mock transport.

Do not require a live Jellyfin server for normal automated test execution.

## Definition of Done

`v0.0.4` is complete when the application can reliably:

- validate a Jellyfin server;
- enforce the supported server-version policy;
- issue authenticated-capable requests;
- return normalized results/errors;
- test networking logic without real infrastructure.

---

# v0.0.5 — Authentication, Servers & Sessions

## Goal

Implement the first complete real user journey:

> Add a server → validate it → log in → persist the session → restore it on restart → switch/logout.

## Why This Is a Separate Release

Authentication is the first production feature that exercises:

- networking;
- persistence needs;
- secure storage;
- navigation;
- error handling;
- state management;
- account identity.

It also creates the session context required by every later media feature.

## Required Work

### Domain Concepts

Define clear concepts for:

- server;
- Jellyfin user;
- credential/session token;
- saved profile/account;
- active profile.

Do not treat these as interchangeable.

### Server Setup

Implement:

- server URL entry;
- URL normalization;
- connection validation;
- Jellyfin identification;
- version compatibility check;
- useful connection errors.

### Login

Implement Jellyfin credential authentication.

Provide polished states for:

- connecting;
- invalid credentials;
- unreachable server;
- unsupported server;
- TLS/certificate problems where identifiable;
- server error.

Never expose raw networking exception text as the primary UI.

### Secure Storage

Store sensitive credentials/tokens using appropriate platform secure storage.

Do not store secrets in ordinary preferences or logs.

### Saved Servers and Users

Support the architecture for:

- multiple servers;
- multiple saved users per server;
- selecting an active server/user combination.

The first UI can remain simple.

### Session Restore

On application restart:

- restore saved profile information;
- restore valid session context;
- avoid forcing unnecessary login;
- handle unavailable servers gracefully.

The application must remain able to launch meaningfully even if the last server is currently offline.

### Logout / Removal

Support:

- logout;
- removal of saved users;
- removal of saved servers;
- clearing associated secure credentials.

### Navigation Integration

Unauthenticated users should enter onboarding/login.

Authenticated users should enter the application shell.

## Tests

Prioritize TDD around:

- successful authentication;
- invalid credentials;
- unsupported server version;
- session persistence;
- switching;
- logout;
- server-unavailable-at-startup behavior.

## Definition of Done

`v0.0.5` is complete when a user can install Jellyfinity, connect to Jellyfin 10.11.6+, authenticate, restart the application, retain the saved session, and manage saved server/user identities with clear feedback.

---

# v0.0.6 — Persistence, Cache & Local Data Foundation

## Goal

Create the local data architecture required for large libraries, cached UI, persistent state, and later offline downloads.

## Why This Is a Separate Release

Jellyfinity must not become:

```text
Widget → Jellyfin API → JSON → Widget
```

Offline behavior, fast startup, partial availability, persistent queues, and 130k-song libraries require local persistence to be a foundational concern.

This release establishes that foundation before the music UI depends on network-only data.

## Required Work

### Local Database

Choose and integrate the local persistence technology.

Evaluate:

- large dataset performance;
- indexing;
- migrations;
- Flutter platform support;
- testing;
- query ergonomics;
- maintenance;
- dependency longevity.

Record the decision in an ADR.

### Schema and Migration Policy

Create a migration strategy from the beginning.

Do not assume the database can simply be deleted on every application update.

### Cache Semantics

Define distinctions between:

- persisted metadata;
- temporary cache;
- artwork cache;
- user-authored local state;
- downloadable media state.

### Repository Source Strategy

Establish conventions for repositories that may combine:

- local sources;
- remote Jellyfin sources.

The UI should not need to know which source supplied the data.

### Artwork

Define artwork cache behavior and invalidation strategy.

Avoid unbounded memory and disk use.

### Preferences

Provide structured persistent storage for non-sensitive application settings.

### Scale

Exercise local operations at data volumes representative of at least the development library:

- ~130k tracks;
- ~500 movies;
- ~4k episodes.

The design should remain capable of scaling higher.

## Tests

Add tests for:

- migrations;
- repository source precedence;
- cached reads;
- stale data behavior;
- partial data;
- database queries at representative scale where practical.

## Definition of Done

`v0.0.6` is complete when Jellyfinity has a documented and tested local-data architecture that future media features can rely on for:

- cache;
- offline-tolerant presentation;
- large libraries;
- persistent application state.

---

# v0.0.7 — Media Domain & Repository Contracts

## Goal

Define Jellyfinity's stable media vocabulary and map Jellyfin API data into it.

## Why This Is a Separate Release

The application should not spread raw Jellyfin response objects throughout UI and business logic.

Music implementation is much easier to evolve when the domain model and repository contracts are already explicit.

Movies and television should also be represented enough to prevent the architecture from becoming music-specific.

## Required Work

### Domain Entities

Define the necessary initial domain concepts, including likely forms of:

- Artist;
- Album;
- Track;
- Playlist;
- Movie;
- Series;
- Season;
- Episode;
- MediaImage;
- MediaAvailability;
- PlaybackProgress.

Implement only fields that currently serve known behavior.

Do not mirror every Jellyfin API field automatically.

### Identity

Define how Jellyfinity represents server-owned media identity.

The architecture should leave room for future portable/shareable media identity without implementing it now.

### Availability

Model important availability concepts, such as:

- remote only;
- local + remote;
- local only;
- remote unavailable;
- partially available.

### Repository Contracts

Create domain-facing repository contracts for media retrieval.

Examples may include:

- music library;
- playlists;
- media metadata;
- artwork;
- playback progress.

Avoid a single giant repository interface.

### Jellyfin Mapping

Map Jellyfin API DTOs to Jellyfinity domain models.

Keep mapping logic centralized and tested.

### Partial Data

Ensure models and repository behavior can represent meaningful partial information instead of treating all incomplete API responses as total failure.

## Tests

Use TDD for:

- DTO → domain mapping;
- availability state;
- partial media;
- repository contracts;
- identity behavior.

## Definition of Done

`v0.0.7` is complete when production features can consume Jellyfinity domain entities without depending on raw Jellyfin transport models.

---

# v0.0.8 — Music Library Experience

## Goal

Build the first substantial media feature: browsing and using a very large Jellyfin music library.

## Why This Is a Separate Release

This release proves that the foundational architecture can support real, high-volume user-facing media features before playback complexity is introduced.

It also validates Jellyfinity's UX identity.

## Required Work

### Music Navigation

Implement the initial Music section.

### Library Browsing

Support at minimum:

- artists;
- albums;
- tracks where appropriate;
- album details;
- artist details sufficient for normal browsing.

### Large Library Behavior

The feature must behave well with the real development scale of roughly 130k songs.

Use:

- pagination/incremental loading;
- server-side queries;
- local indexes;
- virtualized lists;
- sensible caching.

Avoid fetching or filtering the complete library in Dart memory.

### Artwork

Display cached/progressive artwork gracefully.

### Loading UX

Use skeletons or known layout structures instead of generic page-level indefinite spinners.

### Partial Failure

A failed item should not unnecessarily invalidate its surrounding collection.

Unavailable tracks should remain visible where useful and be clearly marked.

### Music-Scoped Search

Implement an initial search behavior suitable for music.

At this stage, keeping the search scoped to music is acceptable and may be preferable.

Prioritize:

- artists;
- albums;
- songs;
- playlists if playlist support exists by this point.

### Cached Browsing

Previously loaded music metadata should remain usefully browsable when the server becomes unavailable.

## Tests

Cover:

- large paginated collections;
- loading states;
- partial data;
- cached data;
- offline/unreachable server presentation;
- navigation between artist/album/track views;
- search behavior.

## Definition of Done

`v0.0.8` is complete when the user can browse a large Jellyfin music library comfortably and the application already demonstrates Jellyfinity's intended loading, caching, error, and navigation quality.

---

# v0.0.9 — Audio Playback & Persistent Queue

## Goal

Turn the music library into a real music application.

## Why This Is a Separate Release

Playback is sufficiently complex to deserve an explicit release boundary.

It combines:

- media engine integration;
- queue ownership;
- background execution;
- lifecycle handling;
- Android/iOS media controls;
- persistence;
- UI synchronization.

Isolating it as its own milestone makes failures and design decisions easier to reason about.

## Required Work

### Playback Engine

Select and integrate the audio playback engine.

Record the decision in an ADR.

The engine must be assessed for:

- Android support;
- iOS support;
- background playback;
- system media controls;
- gapless playback;
- seeking;
- queue behavior;
- format support;
- lifecycle stability.

### Gapless Playback

Gapless playback is a core requirement.

Do not rely solely on package claims.

Create automated or repeatable verification where practical.

### Playback Domain

Playback state should not live only inside package-specific classes.

Define application-facing playback concepts.

### Persistent Queue

Implement a queue owned by Jellyfinity.

Support:

- inspect queue;
- reorder;
- remove;
- clear;
- Add to Queue;
- Play Next;
- shuffle;
- repeat;
- restore queue after restart where practical.

### Now Playing

Implement:

- full player screen;
- persistent mini-player;
- current artwork;
- track information;
- seek/progress;
- play/pause;
- next/previous;
- queue access.

### Background Playback

Playback should continue appropriately when the application leaves the foreground.

### System Integration

Implement appropriate:

- lock-screen controls;
- notification/media session controls;
- headset/Bluetooth controls where provided by the platform stack.

### Playback Failures

Unavailable or failed tracks should produce useful local feedback without destroying the queue or returning the user to an unrelated screen.

### Quality

Prepare playback-quality configuration architecture.

Full transcoding/quality sophistication can evolve later, but the model should not assume only one stream quality forever.

### Optional if Reasonable

Lyrics may be introduced if the required Jellyfin data and playback stack make them straightforward.

Synchronized lyric sophistication should not block `v0.1.0`.

## Tests

Prioritize:

- queue manipulation;
- queue persistence;
- playback state transitions;
- unavailable track handling;
- restart restoration;
- presentation synchronization.

Platform integration tests should be added where feasible.

## Definition of Done

`v0.0.9` is complete when Jellyfinity can function as a real Android/iOS music player using a Jellyfin library, including persistent queue behavior and background playback.

---

# v0.1.0 — First Usable Music Vertical Slice

## Goal

Ship the first coherent version of Jellyfinity that the developer and initial users can credibly use day to day for music.

## Why This Is a Separate Release

`v0.1.0` marks the transition from architectural milestones to the first integrated product milestone.

It should not merely contain all previous code.

The combined workflow must be polished as one experience.

## Required User Journey

A user should be able to:

1. install Jellyfinity;
2. launch it;
3. add a Jellyfin 10.11.6+ server;
4. authenticate;
5. restart the application without losing the session;
6. open Music;
7. browse a very large library;
8. browse artists and albums;
9. search music;
10. play a track;
11. control playback from the mini-player and Now Playing screen;
12. build and manipulate a queue;
13. leave the app while audio continues;
14. return later and recover useful playback/queue state;
15. understand loading, offline, partial, unavailable, and failed states.

## Required Quality

Before tagging `v0.1.0`:

- no known critical authentication failures;
- no known destructive queue bugs;
- no common raw exception leakage into the UI;
- core workflows covered by unit/widget/integration tests;
- Android and iOS manually validated;
- performance is acceptable on the ~130k-song development library;
- changelog is complete;
- relevant ADRs are current;
- contributor setup still works from a clean clone;
- CI passes on the release commit.

## Explicitly Not Required for v0.1.0

The following are intentionally deferred:

- complete offline downloads;
- movies;
- television;
- cross-server unified libraries;
- social sharing;
- collaborative playlists;
- full theme editor;
- plugin framework;
- desktop clients;
- Android TV;
- advanced recommendations;
- comprehensive accessibility work;
- full synchronized-lyrics experience;
- complete crossfade/ReplayGain sophistication if the playback stack requires additional work.

These belong to later development and should be tracked in `OUTLOOK.md`.

---

# Release Discipline

For every release in this roadmap:

1. define issues or tasks before implementation where practical;
2. develop on focused branches;
3. use meaningful commits;
4. add or update tests with behavior changes;
5. update documentation/ADRs when architectural behavior changes;
6. use pull requests even for solo development when useful for preserving reviewable history;
7. require CI before merge;
8. update `CHANGELOG.md`;
9. tag releases semantically.

The repository should read like a real collaborative engineering project, not a sequence of unstructured personal snapshots.
