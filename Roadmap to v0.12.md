# Jellyfinity v0.12.x specifications

Read only the assigned version. This arc adds no new music-domain feature. It
turns the feature-complete client into a supportable, distributable public
product and closes every release blocker before v1.0.0.

## Big goal - Public-release foundation

Make Jellyfinity safe to install, upgrade, diagnose, distribute, and support in
public while preserving its privacy-first, self-hosted character.

## v0.12.0 - Onboarding and account readiness

**Goal:** Make reaching a first successful listen and managing later profiles
clear enough for a public audience.

**Required:**

- Refine welcome, server entry, URL normalization, validation, authentication,
  profile selection, first sync, and first playable-library transitions.
- Distinguish DNS, TLS, timeout, unsupported server, wrong base path,
  authentication, authorization, empty library, and offline failures with
  actionable user language.
- Complete add/switch/sign-out/remove flows for multiple profiles and servers,
  including explicit consequences for downloads, pending intents, connected
  sessions, history, and local preferences.
- Preserve credentials in platform-secure storage and prevent diagnostic UI,
  clipboard actions, logs, and screenshots from exposing tokens.
- Test fresh install, migration, bad endpoints, self-signed/local HTTP policy,
  server upgrades, account isolation, keyboard/TV entry, and recovery.

**Done when:** A new user can connect safely and an existing user can understand
and recover every common account/server state without developer assistance.

## v0.12.1 - Privacy and security qualification

**Goal:** Verify that a public build keeps credentials, listening activity, and
local media under the user's control.

**Required:**

- Threat-model authentication, authenticated URLs, logs, connected playback,
  downloads, local-only files, database contents, image/file picking, and
  exported diagnostics.
- Audit transport security decisions and warnings without breaking intentional
  LAN HTTP support; never downgrade or trust certificates silently.
- Verify secure credential storage, profile/server deletion, redaction,
  temporary files, platform backups, and least-required native permissions.
- Make any crash-reporting decision explicit, opt-in where applicable, data
  minimized, documented, and replaceable; unnecessary telemetry remains absent.
- Add dependency/license review, secret scanning, security tests, and a
  responsible vulnerability-reporting path.

**Done when:** The shipped privacy claims are backed by tested behavior and no
routine diagnostic, lifecycle, or sharing path leaks sensitive data.

## v0.12.2 - Performance and stability qualification

**Goal:** Prove the complete music client remains responsive and bounded at the
repository's documented scale.

**Required:**

- Establish repeatable benchmarks for startup, Home, library paging, search,
  artwork, queue, playlists, downloads, discovery, database growth, and memory.
- Test approximately 130k songs plus large artists/playlists, long histories,
  long-lived TV sessions, background work, and multiple saved accounts.
- Remove unbounded reads, rebuilds, streams, timers, caches, retries, and disk
  scans discovered by profiling; preserve partial usable state while tuning.
- Run soak and failure-injection tests across network loss, server restart,
  playback errors, storage pressure, sleep/wake, and repeated account switches.
- Define release thresholds and regression signals for Android and Windows,
  with applicable television and iOS measurements.

**Done when:** Performance and stability have measurable release thresholds and
the full music product meets them at normal large-library scale.

## v0.12.3 - Upgrade and compatibility qualification

**Goal:** Make installing v1 over any supported Jellyfinity release predictable
and document exactly which Jellyfin servers work.

**Required:**

- Test every supported database migration path, interrupted migration, restart,
  corrupt optional cache, queued background work, and retained local-only file.
- Define recoverable failure and rollback behavior. Never destroy downloads or
  credentials merely because derived state can be rebuilt.
- Validate the minimum Jellyfin server and a representative supported-version
  matrix for authentication, music reads, playback, playlists, downloads,
  lyrics, discovery, and connected control.
- Feature-detect optional server capabilities and provide explicit unavailable
  states rather than version-string guesses or undocumented compatibility hacks.
- Publish migration, backup, compatibility, known-limit, and support-lifecycle
  documentation from the same matrix exercised by CI/manual acceptance.

**Done when:** Users can upgrade without losing irreplaceable local state and
can determine compatibility before depending on a server/client combination.

## v0.12.4 - Reproducible builds and distribution

**Goal:** Produce verifiable installation artifacts through repeatable,
documented release automation.

**Required:**

- Create pinned, reproducible release workflows for supported Android and
  Windows artifacts and the macOS/Xcode path required for iOS.
- Separate signing credentials from source and logs, document rotation and
  recovery, and allow contributors to reproduce equivalent unsigned artifacts.
- Generate version metadata, checksums, notices/licenses, symbols where safe,
  update metadata, and provenance required by selected distribution channels.
- Validate clean install, upgrade, uninstall data behavior, launcher metadata,
  package identity, network permissions, media integration, and release-mode
  behavior for every artifact.
- Prepare store/repository automation without publishing v1.0.0 early; failed
  publication must be repeatable and must not require rebuilding different bits.

**Done when:** A tagged commit can produce reviewable release artifacts
repeatably and securely, ready for but not yet declared as v1.0.0.

## v0.12.5 - Release candidate acceptance

**Goal:** Freeze features and prove one candidate across the complete public
music experience.

**Required:**

- Freeze schema, protocol, dependencies, copy, assets, and supported-platform
  matrix except for release-blocking fixes.
- Run the full automated suite, static analysis, release builds, migration and
  compatibility matrices, performance thresholds, and security/privacy checks.
- Complete physical acceptance for Android phone/tablet, Windows, Android TV,
  Fire TV, and the documented iOS scope across install, upgrade, onboarding,
  browse, search, curate, download, offline, play, and connected control.
- Triage every known issue into blocker, documented limitation, or post-v1 work;
  no silent data-loss, credential, playback-ownership, or primary-flow failure
  can be deferred.
- Finalize release notes, user/support documentation, screenshots, store
  metadata, licenses, privacy declarations, contribution process, and rollback
  plan.

**Done when:** One immutable candidate satisfies every v1.0 entry criterion and
the only remaining action is to publish and tag that exact build.

## Non-goals for v0.12.x

New music features, movies, shows, social/collaborative systems, unified
multi-server libraries, a plugin framework, unrelated backends, and publishing
an artifact under the v1.0.0 version before acceptance are outside this arc.
