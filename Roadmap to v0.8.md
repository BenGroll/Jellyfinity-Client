# Jellyfinity v0.8.x specifications

Read only the assigned version. This arc makes music downloads maintain
themselves after the user chooses what should stay available. Every patch must
preserve local-only media, profile/server isolation, bounded storage work,
Android and Windows support, and existing iOS behavior.

## Big goal - Autonomous offline music

Downloaded music should remain ready without repeated manual repair. Automation
is always opt-in, visible, reversible, and subordinate to the rule that a local
file may outlive its server item.

## v0.8.0 - Durable background download execution

**Goal:** Make queued music downloads resumable application work rather than a
foreground-screen activity.

**Required:**

- Persist enough job, source, owner, progress, retry, and policy state to resume
  interrupted downloads without duplicating files or ownership claims.
- Move execution behind a platform-neutral scheduler contract with Android and
  Windows implementations appropriate to each lifecycle. Preserve an iOS-safe
  implementation without promising unsupported unlimited background time.
- Revalidate authentication, network policy, free space, remote source, and
  partial file state whenever a job resumes after process or device restart.
- Expose queued, waiting, running, paused, retrying, completed, and terminal
  states consistently in Downloads and system surfaces.
- Bound concurrency, retry, wakeups, and battery/network use; cancellation and
  account/server removal must clean up only the targeted jobs and claims.
- Test process death, restart, duplicate scheduling, expired sessions, partial
  files, network transitions, and platform scheduler adapters.

**Done when:** A large album, artist, or playlist download can survive ordinary
backgrounding and restart and either completes or explains exactly why it waits.

## v0.8.1 - Automatic playlist download synchronization

**Goal:** Keep an explicitly subscribed playlist available as its server
membership changes.

**Required:**

- Separate one-time playlist download from an opt-in synchronized subscription
  with its own profile/server-scoped policy and last confirmed snapshot.
- Reconcile additions, removals, duplicates, order, rename, artwork, and server
  deletion incrementally. New members join the durable job system.
- Never delete a file still claimed by another album, artist, playlist, smart
  rule, standalone download, or local-only retention decision.
- Make removal policy explicit: keep removed songs as standalone downloads or
  release only this playlist's claim. Default to the non-destructive choice.
- Show pending, partially synchronized, paused-by-policy, conflict, and failed
  states without making the downloaded snapshot unplayable.
- Test large and rapidly edited playlists, duplicate rows, offline changes,
  retries, account switches, and smart-playlist output from v0.7.x.

**Done when:** A subscribed playlist updates its offline copy safely and the
user can always see what is current, pending, retained, or unavailable.

## v0.8.2 - Collection smart synchronization

**Goal:** Let users keep evolving artists and selected music scopes available
without manually downloading every new release.

**Required:**

- Add opt-in synchronization policies for a downloaded artist and other bounded
  music collections already represented by Jellyfinity's domain.
- Discover new eligible music through paged server queries and the last
  confirmed sync cursor/snapshot; never scan or materialize the entire library.
- Allow clear inclusion limits such as future additions, release types, and a
  maximum retained count where the server exposes trustworthy metadata.
- Reuse existing files and claims, preserve deliberate exclusions, and never
  infer deletion of local-only music from absence in a partial server response.
- Integrate scheduled work, manual refresh, progress, pause, and failure states
  with the same download-management surface used by playlist subscriptions.
- Test sparse metadata, backdated releases, pagination changes, server removal,
  policy edits, and mixed ownership.

**Done when:** A chosen artist or collection can stay current offline through an
explicit, bounded policy without becoming an uncontrolled library mirror.

## v0.8.3 - Storage budgets and reservations

**Goal:** Let users decide how much space automatic music downloads may consume.

**Required:**

- Add global and, where useful, profile-scoped automatic-download budgets while
  keeping manually retained and local-only music visibly outside eviction.
- Estimate and reserve space before scheduling batches, reconcile estimates
  with completed file sizes, and avoid overcommitting across concurrent jobs.
- Distinguish device free space, Jellyfinity usage, reserved work, configured
  budget, and space that cannot be measured on a platform.
- Pause rather than fail work when a budget or safe-space floor is reached, and
  show which policy must change before it can continue.
- Test unknown sizes, transcoded sizes, concurrent reservations, changed
  settings, external file removal, multiple profiles, and platform probe
  failures.

**Done when:** Automatic downloads cannot unexpectedly consume unbounded storage
and a paused batch gives the user an accurate path forward.

## v0.8.4 - Retention and automatic cleanup

**Goal:** Reclaim eligible automatic-download storage without threatening music
the user deliberately kept.

**Required:**

- Define conservative retention candidates from explicit automatic ownership,
  listening recency, subscription membership, and configurable age/count rules.
- Exclude standalone manual downloads, local-only items, Favorites when the
  selected policy protects them, in-progress files, and anything with another
  active owner claim.
- Preview the exact files and reclaimed estimate before enabling a policy; make
  manual cleanup and automatic decisions use the same tested planner.
- Apply cleanup transactionally to claims, catalog, queue availability, cached
  metadata, and files. Partial filesystem failure remains retryable and visible.
- Keep an on-device audit of recent automatic removals without storing listening
  analytics or exposing another profile's activity.
- Test every protection rule, races with playback/download, stale probes,
  restart, rollback, and account/server removal.

**Done when:** Jellyfinity can stay within an agreed storage budget and can
explain every automatic removal, while protected music is never selected.

## v0.8.5 - Offline automation hardening

**Goal:** Make background work, synchronization, budgets, and cleanup dependable
as one offline lifecycle.

**Required:**

- Exercise download, subscription, smart sync, reservation, cleanup, offline
  playback, queue, Favorites, and account removal together over long runs.
- Repair database/file mismatches, abandoned reservations, duplicate jobs,
  interrupted cleanup, changed server identities, and obsolete policy versions.
- Bound scheduler wakeups, queries, disk scans, memory, and network traffic for
  the documented library scale and long-lived Android/TV installations.
- Complete Android and Windows background/lifecycle acceptance and preserve iOS
  behavior within its platform limits.
- Add migration, downgrade/rollback documentation, observability with redacted
  local logs, and failure-injection integration tests.

**Done when:** Offline music maintains itself through real lifecycle, storage,
network, and server changes without deleting irreplaceable media or hiding work.

## Non-goals for v0.8.x

Video downloads, cloud backup, cross-device transfer of downloaded files,
unbounded whole-library mirroring, mandatory automatic cleanup, and deleting
local-only media are outside this arc.
