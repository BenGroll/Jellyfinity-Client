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
| v0.1.2 | Playlist curation | Implemented (reorder completed in v0.4.2) | [spec](Roadmap%20to%20v0.2.md#v012--playlist-curation) |
| v0.1.3 | Crossfade | Implemented | [spec](Roadmap%20to%20v0.2.md#v013--crossfade) |
| v0.1.4 | Volume normalization | Implemented | [spec](Roadmap%20to%20v0.2.md#v014--volume-normalization) |
| v0.1.5 | Lyrics | Implemented | [spec](Roadmap%20to%20v0.2.md#v015--lyrics) |
| v0.1.6 | Interface refresh | Implemented | [spec](Roadmap%20to%20v0.2.md#v016--interface-refresh) |
| v0.2.0 | Downloaded tracks and albums | Implemented | [spec](Roadmap%20to%20v0.3.md#v020--downloaded-tracks-and-albums) |
| v0.2.1 | Downloadable playlists | Implemented | [spec](Roadmap%20to%20v0.3.md#v021--downloadable-playlists) |
| v0.2.2 | Artist downloads, quality, and management | Implemented | [spec](Roadmap%20to%20v0.3.md#v022--artist-downloads-download-quality-and-management) |
| v0.2.3 | Offline library and recovery | Implemented | [spec](Roadmap%20to%20v0.3.md#v023--offline-library-and-recovery) |
| v0.3.0 | Offline music completion | Implemented (feature half completed in v0.3.6) | [spec](Roadmap%20to%20v0.3.md#v030--offline-music-completion) |
| v0.3.1 | Listening history | Implemented | [spec](Roadmap%20to%20v0.4.md#v031--listening-history) |
| v0.3.2 | Continue listening and recently played | Implemented | [spec](Roadmap%20to%20v0.4.md#v032--continue-listening-and-recently-played) |
| v0.3.3 | Recently added | Implemented | [spec](Roadmap%20to%20v0.4.md#v033--recently-added) |
| v0.3.4 | Favorites as a place | Implemented | [spec](Roadmap%20to%20v0.4.md#v034--favorites-as-a-place) |
| v0.3.5 | Related artists and albums | Implemented | [spec](Roadmap%20to%20v0.4.md#v035--related-artists-and-albums) |
| v0.3.6 | Offline music completion, finished | Implemented | [spec](Roadmap%20to%20v0.3.md#v030--offline-music-completion) |
| v0.4.0 | Home completion | Planned | [spec](Roadmap%20to%20v0.4.md#v040--home-completion) |
| v0.4.1 | Music listening perfection | Implemented | [spec](Roadmap%20to%20v0.5md#v040--music-listening-perfection) |
| v0.4.2 | Playlist mastery | Implemented | [spec](Roadmap%20to%20v0.5md#v041--playlist-mastery) |
| v0.4.3 | Offline Favorites | Implemented | [spec](Roadmap%20to%20v0.5md#v042--offline-favorites) |
| v0.4.4 | Library exploration | Implemented | [spec](Roadmap%20to%20v0.5md#v043--library-exploration) |
| v0.4.5 | Random discovery and a personal mix | Implemented | [ADR-only](docs/adr/ADR-0035-random-discovery-and-personal-mix.md) |
| v0.4.6 | Fire TV platform support | Implemented (device acceptance pending) | [ADR-only](docs/adr/ADR-0036-fire-tv-platform-support.md) |
| v0.5.0 | Personal music discovery | Planned (its Home-mix entry point shipped early, in v0.4.5) | [spec](Roadmap%20to%20v0.5md#v044--personal-music-discovery) |
| v0.5.1 | Connected playback contract | Implemented | [spec](Roadmap%20to%20v0.6.md#v051---connected-playback-contract), [ADR](docs/adr/ADR-0037-connected-playback-contract.md) |
| v0.5.2 | Device presence and capability transport | Implemented | [spec](Roadmap%20to%20v0.6.md#v052---device-presence-and-capability-transport), [ADR](docs/adr/ADR-0038-device-presence-and-capability-transport.md) |
| v0.5.3 | Remote state and command execution | Implemented | [spec](Roadmap%20to%20v0.6.md#v053---remote-state-and-command-execution) |
| v0.5.4 | Atomic playback handoff | Implemented | [spec](Roadmap%20to%20v0.6.md#v054---atomic-playback-handoff) |
| v0.5.5 | Device picker and ownership UI | Implemented | [spec](Roadmap%20to%20v0.6.md#v055---device-picker-and-ownership-ui) |
| v0.5.6 | Remote Now Playing and queue controls | Implemented | [spec](Roadmap%20to%20v0.6.md#v056---remote-now-playing-and-queue-controls), [ADR](docs/adr/ADR-0040-remote-now-playing-and-queue-controls.md) |
| v0.5.7 | Windows connected playback | Implemented (device acceptance pending) | [spec](Roadmap%20to%20v0.6.md#v057---windows-connected-playback), [ADR](docs/adr/ADR-0041-windows-connected-playback.md) |
| v0.5.8 | Android connected playback | Implemented (device acceptance pending) | [spec](Roadmap%20to%20v0.6.md#v058---android-connected-playback), [ADR](docs/adr/ADR-0042-android-connected-playback.md) |
| v0.5.9 | Android TV and Fire TV connected playback | Implemented (device acceptance pending) | [spec](Roadmap%20to%20v0.6.md#v059---android-tv-and-fire-tv-connected-playback), [ADR](docs/adr/ADR-0043-android-tv-and-fire-tv-connected-playback.md) |
| v0.6.0 | True cross-device playback | Implemented (device acceptance pending) | [spec](Roadmap%20to%20v0.6.md#v060---true-cross-device-playback), [ADR](docs/adr/ADR-0047-remote-selection-routing.md) |
| v0.6.1 | Settings as places | Planned | [spec](Roadmap%20to%20v0.7.md#v061---settings-as-places) |
| v0.6.0 | True cross-device playback | Planned (respecced: adds group playback, volume, and a Remote destination) | [spec](Roadmap%20to%20v0.6.md#v060---true-cross-device-playback) |
| v0.6.1 | Settings as places | Planned | [spec](Roadmap%20to%20v0.6.1.md#v061---settings-as-places) |
| v0.7.0 | Bulk music selection and playlist actions | Planned | [spec](Roadmap%20to%20v0.7.md#v070---bulk-music-selection-and-playlist-actions) |
| v0.7.1 | Playlist artwork management | Planned | [spec](Roadmap%20to%20v0.7.md#v071---playlist-artwork-management) |
| v0.7.2 | Smart playlist rules and preview | Planned | [spec](Roadmap%20to%20v0.7.md#v072---smart-playlist-rules-and-preview) |
| v0.7.3 | Smart playlist publication and refresh | Planned | [spec](Roadmap%20to%20v0.7.md#v073---smart-playlist-publication-and-refresh) |
| v0.7.4 | Playlist-system hardening | Planned | [spec](Roadmap%20to%20v0.7.md#v074---playlist-system-hardening) |
| v0.8.0 | Durable background download execution | Planned | [spec](Roadmap%20to%20v0.8.md#v080---durable-background-download-execution) |
| v0.8.1 | Automatic playlist download synchronization | Planned | [spec](Roadmap%20to%20v0.8.md#v081---automatic-playlist-download-synchronization) |
| v0.8.2 | Collection smart synchronization | Planned | [spec](Roadmap%20to%20v0.8.md#v082---collection-smart-synchronization) |
| v0.8.3 | Storage budgets and reservations | Planned | [spec](Roadmap%20to%20v0.8.md#v083---storage-budgets-and-reservations) |
| v0.8.4 | Retention and automatic cleanup | Planned | [spec](Roadmap%20to%20v0.8.md#v084---retention-and-automatic-cleanup) |
| v0.8.5 | Offline automation hardening | Planned | [spec](Roadmap%20to%20v0.8.md#v085---offline-automation-hardening) |
| v0.9.0 | Rich music metadata contracts | Planned | [spec](Roadmap%20to%20v0.9.md#v090---rich-music-metadata-contracts) |
| v0.9.1 | Album presentation | Planned | [spec](Roadmap%20to%20v0.9.md#v091---album-presentation) |
| v0.9.2 | Artist presentation | Planned | [spec](Roadmap%20to%20v0.9.md#v092---artist-presentation) |
| v0.9.3 | Artwork pipeline and presentation | Planned | [spec](Roadmap%20to%20v0.9.md#v093---artwork-pipeline-and-presentation) |
| v0.9.4 | Sorting, filtering, and fast navigation | Planned | [spec](Roadmap%20to%20v0.9.md#v094---sorting-filtering-and-fast-navigation) |
| v0.9.5 | Contextual music search | Planned | [spec](Roadmap%20to%20v0.9.md#v095---contextual-music-search) |
| v0.10.0 | Home completion | Planned (carries v0.4.0 requirements) | [spec](Roadmap%20to%20v0.10.md#v0100---home-completion) |
| v0.10.1 | Listening history as a destination | Planned | [spec](Roadmap%20to%20v0.10.md#v0101---listening-history-as-a-destination) |
| v0.10.2 | Private recommendation candidates and ranking | Planned (carries v0.5.0 requirements) | [spec](Roadmap%20to%20v0.10.md#v0102---private-recommendation-candidates-and-ranking) |
| v0.10.3 | Discovery surfaces and explanations | Planned | [spec](Roadmap%20to%20v0.10.md#v0103---discovery-surfaces-and-explanations) |
| v0.10.4 | Music Home section control | Planned | [spec](Roadmap%20to%20v0.10.md#v0104---music-home-section-control) |
| v0.10.5 | Personalization hardening | Planned | [spec](Roadmap%20to%20v0.10.md#v0105---personalization-hardening) |
| v0.11.0 | Adaptive music shell and input contracts | Planned | [spec](Roadmap%20to%20v0.11.md#v0110---adaptive-music-shell-and-input-contracts) |
| v0.11.1 | Windows music workspace | Planned | [spec](Roadmap%20to%20v0.11.md#v0111---windows-music-workspace) |
| v0.11.2 | Android phone and tablet completion | Planned | [spec](Roadmap%20to%20v0.11.md#v0112---android-phone-and-tablet-completion) |
| v0.11.3 | Android TV and Fire TV completion | Planned | [spec](Roadmap%20to%20v0.11.md#v0113---android-tv-and-fire-tv-completion) |
| v0.11.4 | iOS music compatibility completion | Planned | [spec](Roadmap%20to%20v0.11.md#v0114---ios-music-compatibility-completion) |
| v0.11.5 | Accessibility and input acceptance | Planned | [spec](Roadmap%20to%20v0.11.md#v0115---accessibility-and-input-acceptance) |
| v0.12.0 | Onboarding and account readiness | Planned | [spec](Roadmap%20to%20v0.12.md#v0120---onboarding-and-account-readiness) |
| v0.12.1 | Privacy and security qualification | Planned | [spec](Roadmap%20to%20v0.12.md#v0121---privacy-and-security-qualification) |
| v0.12.2 | Performance and stability qualification | Planned | [spec](Roadmap%20to%20v0.12.md#v0122---performance-and-stability-qualification) |
| v0.12.3 | Upgrade and compatibility qualification | Planned | [spec](Roadmap%20to%20v0.12.md#v0123---upgrade-and-compatibility-qualification) |
| v0.12.4 | Reproducible builds and distribution | Planned | [spec](Roadmap%20to%20v0.12.md#v0124---reproducible-builds-and-distribution) |
| v0.12.5 | Release candidate acceptance | Planned | [spec](Roadmap%20to%20v0.12.md#v0125---release-candidate-acceptance) |
| v1.0.0 | Jellyfinity Music - first official release | Planned | [spec](Roadmap%20to%20v1.0.md#v100---first-official-release) |

Historical implementation notes live in CHANGELOG.md and the linked ADRs. Future ideas in OUTLOOK.md are out of scope unless promoted into this index.
