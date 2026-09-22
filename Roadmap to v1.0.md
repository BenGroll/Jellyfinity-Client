# Jellyfinity v1.0.0 specification

Read this specification only after every planned music version through v0.12.5
is implemented. v1.0.0 adds no new feature, schema, protocol, dependency, or
platform. It publishes the exact release candidate accepted in v0.12.5.

## Big goal - Jellyfinity Music

Ship the first official Jellyfinity release: a private, self-hosted music client
whose library, playlists, downloads, playback, connected controls, discovery,
and platform experiences are complete enough to depend on every day.

## v1.0.0 - First official release

**Goal:** Publish the exact accepted v0.12.5 candidate as Jellyfinity Music,
without adding or changing feature behavior.

## Product promise

- Music is the only first-class media type in v1.0.0. Movies and shows begin in
  later major versions and do not leave placeholder destinations in the app.
- A user can connect to a compatible Jellyfin server, browse and search a large
  music library, curate manual and smart playlists, listen locally or offline,
  move playback between supported devices, and understand every unavailable or
  failed state.
- Listening history and recommendations remain private to the user's device and
  server context. Jellyfinity has no proprietary account, tracking backend,
  advertising, or paid tier.
- Local-only downloads are first-class retained media. Upgrade, reconnect,
  server removal, automation, and cleanup never silently discard them.
- Android and Windows are required release targets. Android TV and Fire TV use
  the shared television experience. Existing iOS local-music support is
  preserved and documented at its validated scope.

## Entry criteria

- Every non-superseded roadmap row through v0.12.5 is Implemented and its
  definition of done is satisfied. Superseded v0.4.0 and v0.5.0 requirements
  are demonstrably completed by v0.10.0 and v0.10.2.
- Every accepted ADR matches the shipped implementation, schema/protocol
  versions are frozen, and `AGENTS.md`, `ROADMAP.md`, `CONTEXT.md`,
  `CHANGELOG.md`, user documentation, and compatibility information agree.
- The v0.12.5 candidate passes the full automated, migration, compatibility,
  performance, privacy/security, release-build, and physical-device matrices
  without a release blocker.
- Installation artifacts are reproducible from the tagged source, signed
  through the documented process, checksummed, accompanied by notices and
  privacy declarations, and identical to the accepted candidate.
- Upgrade and rollback instructions protect credentials, playlists, settings,
  downloads, local-only files, history, and connected-playback state from every
  supported earlier schema.
- Every known limitation is documented in user language with affected platform
  and recovery. A primary music workflow cannot depend on an undocumented
  workaround.

## Release actions

- Set the application/package version to v1.0.0 without changing candidate
  behavior or rebuilding from different source.
- Create the signed tag and release record using the repository's approved
  process, attach the verified artifacts and checksums, and publish the final
  changelog and support/compatibility links.
- Publish through the distribution channels qualified in v0.12.4. A channel
  failure retries the same artifacts and does not produce a different v1.0.0.
- Verify public download/install metadata and perform a short post-publication
  smoke test for clean install, upgrade, sign-in, library load, playback, and
  artifact identity.
- Open the post-v1 planning line only after the release record is complete; do
  not fold a movie, show, social, theme, backend, or plugin feature into the
  release at the last moment.

**Done when:** The accepted candidate is publicly available as v1.0.0 on every
declared channel, installs and upgrades successfully, and the published support
matrix describes exactly the music product users receive.

## Non-goals for v1.0.0

Movies, shows, video playback/downloads, social sharing, collaborative
playlists, unified multi-server libraries, arbitrary Home widgets, a full theme
system, plugins, unrelated media backends, synchronized multi-room playback,
and any feature not already accepted in v0.12.5 are outside this release.
