# Jellyfinity roadmap index

This file is a routing page, not a second specification. Implementation agents
should read `AGENTS.md`, `CONTEXT.md`, and only the linked section for their
assigned version.

Status describes the repository's current development state, not necessarily a
published Git tag.

| Version | Scope | Status | Specification |
| --- | --- | --- | --- |
| v0.0.1 | Repository and project foundation | Implemented | [historical spec](Proof%20Of%20Concept%20Roadmap.md#v001--repository--project-foundation) |
| v0.0.2 | Application architecture core | Implemented | [historical spec](Proof%20Of%20Concept%20Roadmap.md#v002--application-architecture-core) |
| v0.0.3 | Navigation and design system | Implemented | [historical spec](Proof%20Of%20Concept%20Roadmap.md#v003--navigation--design-system) |
| v0.0.4 | Jellyfin transport layer | Implemented | [historical spec](Proof%20Of%20Concept%20Roadmap.md#v004--jellyfin-transport-layer) |
| v0.0.5 | Authentication, servers, and sessions | Implemented | [historical spec](Proof%20Of%20Concept%20Roadmap.md#v005--authentication-servers--sessions) |
| v0.0.6 | Persistence, cache, and local data | Implemented | [historical spec](Proof%20Of%20Concept%20Roadmap.md#v006--persistence-cache--local-data-foundation) |
| v0.0.7 | Media domain and repository contracts | Implemented | [historical spec](Proof%20Of%20Concept%20Roadmap.md#v007--media-domain--repository-contracts) |
| v0.0.8 | Music library experience | Implemented | [historical spec](Proof%20Of%20Concept%20Roadmap.md#v008--music-library-experience) |
| v0.0.9 | Audio playback and persistent queue | Implemented | [historical spec](Proof%20Of%20Concept%20Roadmap.md#v009--audio-playback--persistent-queue) |
| v0.1.0 | First usable music vertical slice | Implemented | [historical spec](Proof%20Of%20Concept%20Roadmap.md#v010--first-usable-music-vertical-slice) |
| v0.1.1 | Streaming quality and transcoding | Implemented | [spec](Roadmap%20to%20v0.2.md#v011--streaming-quality--transcoding) |
| **v0.1.2** | **Playlist curation** | **In progress** | [spec](Roadmap%20to%20v0.2.md#v012--playlist-curation) |
| v0.1.3 | Crossfade | Implemented | [spec](Roadmap%20to%20v0.2.md#v013--crossfade) |
| v0.1.4 | Volume normalization | Implemented | [spec](Roadmap%20to%20v0.2.md#v014--volume-normalization) |
| v0.1.5 | Lyrics | Implemented | [spec](Roadmap%20to%20v0.2.md#v015--lyrics) |
| v0.1.6 | Interface refresh | Implemented | [spec](Roadmap%20to%20v0.2.md#v016--interface-refresh) |
| v0.2.0 | Downloaded tracks and albums | Implemented | [spec](Roadmap%20to%20v0.3.md#v020--downloaded-tracks-and-albums) |
| v0.2.1 | Downloadable playlists | Implemented | [spec](Roadmap%20to%20v0.3.md#v021--downloadable-playlists) |
| v0.2.2 | Artist downloads, quality, and management | Implemented | [spec](Roadmap%20to%20v0.3.md#v022--artist-downloads-download-quality-and-management) |
| v0.2.3 | Offline library and recovery | Implemented | [spec](Roadmap%20to%20v0.3.md#v023--offline-library-and-recovery) |
| v0.3.0 | Offline music completion | Partly implemented | [spec](Roadmap%20to%20v0.3.md#v030--offline-music-completion) |
| v0.4.0 | Listening history | Planned | [spec](Roadmap%20to%20v0.4.md#v040--listening-history) |
| v0.4.1 | Continue listening and recently played | Planned | [spec](Roadmap%20to%20v0.4.md#v041--continue-listening-and-recently-played) |
| v0.4.2 | Recently added | Planned | [spec](Roadmap%20to%20v0.4.md#v042--recently-added) |
| v0.4.3 | Favorites as a place | Planned | [spec](Roadmap%20to%20v0.4.md#v043--favorites-as-a-place) |
| v0.4.4 | Related artists and albums | Planned | [spec](Roadmap%20to%20v0.4.md#v044--related-artists-and-albums) |
| v0.5.0 | Home completion | Planned | [spec](Roadmap%20to%20v0.4.md#v050--home-completion) |

v0.3.0 has shipped its hardening half — the download lifecycle fixes,
regression tests, CI, and release hygiene in `CHANGELOG.md` — plus the
playlist curation v0.1.2 left unfinished, folded in here rather than given
a version of its own. Its remaining offline deliverables are still
outstanding: the entry-point audit across Now Playing, the queue, the
mini-player and inline search; batch retry and batch removal; showing
`MediaAvailability.localOnly` as "Only on this device"; and reclaiming a
removed account's or server's downloaded files. Until those land, the
version's "Done when" is not met.

Future ideas are deliberately unsequenced in `OUTLOOK.md`. They are not part
of a version unless promoted into this index and given a bounded specification.
