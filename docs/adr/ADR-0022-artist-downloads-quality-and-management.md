# ADR-0022: Artist downloads, download quality, and management

## Status

Accepted

## Context

`Roadmap to v0.3.0md` v0.2.2 is the third release in the offline-music
arc: let users manage a meaningful offline collection without losing
control of quality, network use, or device storage. v0.2.0 (ADR-0020)
built the engine, the `DownloadStore`/`DownloadEngine` seams, the
owner-set reference counting, and the track/album controls; v0.2.1
(ADR-0021) added playlists as a third owner kind plus a membership
snapshot. What did not exist: an artist-level download, a download
quality separate from the streaming one, any network policy, and any
screen that shows the whole picture.

Four things had to be settled: how an artist download differs from an
album's, where the download-quality preference lives and how it avoids
rewriting files, how a Wi-Fi-only policy is enforced by a foreground
engine, and what the Downloads screen is a projection of.

## Decision: an artist is a fourth owner kind, paged like nothing else

`DownloadOwnerKind.artist` joins `track`, `album` and `playlist` with no
change to `DownloadOwner`'s shape — exactly as ADR-0020 anticipated. It
uses the same reference counting: "remove this artist" drops the artist
owner from each member track, and a file a standalone download, a
downloaded album, or a downloaded playlist still wants is kept.

Unlike a playlist, an artist needs **no snapshot**. A playlist's order
and membership are the user's arrangement, server-owned and arbitrary; an
artist's discography order is derivable from release date and disc/track
number the same way an album's is, and its membership is "every track the
server credits to them." So an artist download is just owner rows.

The one thing an artist download must do that album and playlist
downloads do not is **never hold the whole collection in memory**. An
album is a few dozen tracks; a prolific artist is thousands.
`downloadArtist` pages `MusicLibraryRepository.tracks(artistId:)` one
window at a time and calls `_request` on each window as it arrives, so
its cost is one page plus the queue. A window that fails after the first
succeeded leaves the artist partially requested rather than failing the
whole thing; "download the missing tracks" in the artist menu completes
it (and picks up anything released since).

## Decision: download quality is a preference, not a per-file record

`SettingsCubit` gains a `downloadQuality` (`StreamQuality`, defaulting to
`original`) and a `downloadsWifiOnly` (`bool`, defaulting to off) —
`ROADMAP.md`'s stated safe starting point, because neither silently
changes what a user gets or blocks a requested download. `StreamQuality`
is reused as the type rather than inventing a parallel enum: it already
models exactly "original/lossless, plus only the tiers Jellyfin can
fulfil", and `JellyfinAudioSourceResolver` already turns it into a
stream address. The two preferences are stored under their own keys and
are fully independent of the streaming quality — a listener can stream
data-saver on the move while keeping lossless copies, or the reverse.

`DownloadsCubit` reads `_settings.state.downloadQuality` at the point it
resolves each transfer's address. That is the whole mechanism, and it is
also why **a quality change never rewrites a file**: a completed download
is never re-fetched, so it simply keeps whatever it was fetched at; only
new requests and retried (failed/paused) ones see the new value. The
quality a given file arrived at is not stored in a column — the file on
disk is the source of truth, and a mixed-quality collection is a
legitimate state, not a bug to reconcile. `SettingsCubit` also moves from
`@injectable` (a factory) to `@lazySingleton`: `PlaybackCubit` and now
`DownloadsCubit` both read and listen to it, and they must see the
instance the settings screen writes to.

## Decision: Wi-Fi-only is a foreground policy with an honest paused state

`connectivity_plus` reports the device's radio status behind a narrow
`NetworkCondition` domain seam (`unmetered` / `metered` / `none`) with a
conservative mapping — Wi-Fi and ethernet are unmetered; cellular,
satellite, VPN and unknown transports are metered, because the platform
will not say what is under a VPN and the whole point of the preference is
not to spend mobile data.

When the preference is on and the connection is metered or absent, a
queued download is moved to a new `DownloadState.waitingForNetwork` —
distinct from `paused` (which the user chose and only an explicit retry
resumes) and from `failed`. The worker skips it; a connectivity change or
a preference change re-queues it. `DownloadsCubit` subscribes to
`NetworkCondition.changes()` and to `SettingsCubit`, so a held download
resumes the moment Wi-Fi returns or the policy is relaxed, without the
user reopening the app.

### The known limitation

`HttpDownloadEngine` is a foreground engine (ADR-0020), so enforcement is
foreground too: a transfer already running when the device drops to
cellular is not interrupted mid-file, and a request made while the app is
backgrounded and offline is only re-evaluated when connectivity next
changes or the app is reopened. This is disclosed in the settings screen
("Enforced while the app is open; a transfer already running is not
interrupted") and is the same tradeoff ADR-0020 documented for the
engine. A future OS background-transfer engine would let the policy be
enforced continuously, with no change above the `NetworkCondition` and
`DownloadEngine` seams.

## Decision: the Downloads screen is a pure projection of the catalog

`DownloadCatalog` already answers every question the screen asks — what
is transferring, what each owner's downloads add up to, how much space
they take — so `DownloadsPage` holds no state of its own. It adds three
derived views to the catalog: `overallStatus` / `storageInUse` (summed
from completed files only), `collectionOwners` (each distinct album,
artist and playlist owner, once), and `standaloneTrackDownloads` (tracks
wanted only by themselves). `CollectionDownloadStatus` gains a
`waitingForNetwork` count and a `storageInUse`.

The per-item controls on the screen are the same `TrackDownloadButton`
used on track rows elsewhere, driven off `record.toTrack()` — retry,
cancel, resume and remove all already live there, so the screen wires
nothing new. Collection names come from the denormalized track records
(an album name, an artist credit), so the screen reads correctly with the
server switched off; a playlist's name is not on the records and falls
back to a labelled generic ("Downloaded playlist") until v0.2.3 gives
downloaded collections their own stored identity.

## Consequences

- No schema change. `waitingForNetwork` and the `artist` owner kind are
  both stored as text in existing columns; `DriftDownloadStore`'s
  unknown-value fallbacks already cover a downgrade.
- `connectivity_plus` is a new dependency — platform-channel work behind
  a replaceable seam, the kind `CONTEXT.md` says a dependency should be.
  `ACCESS_NETWORK_STATE` is added to the Android manifest explicitly.
- `DownloadsCubit` now depends on `SettingsCubit` and `NetworkCondition`,
  and owns two `StreamSubscription`s it cancels on close. It also now
  resolves the *remote* audio source under its `@Named` name rather than
  the bare contract — the local-first resolver would have returned an
  already-downloaded file instead of re-fetching a retried one at the
  new quality.
- An artist download of a track an album already holds fetches nothing;
  it adds an owner. Removing either target leaves the file while the
  other still wants it — the reference counting `ROADMAP.md` v0.2.2 asks
  to be "provable" is the size of the owner set, unchanged since v0.2.0
  and now tested across all four kinds.
- The playback pipeline, queue, crossfade and normalization learn
  nothing new: a downloaded artist's track plays through the exact
  v0.2.0 local-first path.
