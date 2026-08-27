# Jellyfinity Outlook

## Purpose

This document records important product ideas and requirements that belong **after v0.1.0**.

They are intentionally not part of the first music vertical slice.

The purpose of keeping them here is to:

- preserve long-term product intent;
- prevent the v0.1.0 roadmap from expanding uncontrollably;
- help future contributors understand why early architecture should avoid certain dead ends;
- avoid prematurely implementing features that do not yet justify their complexity.

This is not a promised release schedule.

Priorities may change as Jellyfinity is used in practice.

---

# 1. Full Offline Downloads

Offline downloads are one of the most important post-v0.1.0 features.

The desired experience is closer to Spotify/Netflix downloads than a generic file download.

The user should be able to say:

> "I want this to work later exactly as it works now, but without internet."

Download targets should eventually include:

- songs;
- albums;
- artists;
- playlists;
- movies;
- episodes;
- seasons;
- entire shows.

Downloads should remain integrated into the normal media UI.

The same album or movie page should work whether the content is remote, local, or both.

## Local Independence

Downloaded content should remain playable if it disappears from the server.

Such content should become **local only / only on device** rather than being silently removed.

## Future Download Controls

Potential capabilities include:

- Wi-Fi-only downloads;
- independent download quality;
- original/lossless quality;
- storage limits;
- automatic cleanup;
- automatic download of new playlist content;
- smart synchronization;
- automatic next-episode downloads;
- background download management.

---

# 2. Movies

Movies should become a full first-class Jellyfinity experience after the music foundation is stable.

Expected capabilities include:

- browsing;
- Continue Watching;
- recently added;
- favorites;
- collections;
- genres;
- search;
- resume;
- watched state;
- metadata;
- cast;
- versions where useful;
- subtitles/audio selection during playback;
- downloads;
- recommendations where useful.

The exact movie-detail design remains intentionally open.

It should be designed around usability rather than mirroring Jellyfin Web.

---

# 3. Television

Television support should include:

- shows;
- seasons;
- episodes;
- Next Up;
- Continue Watching;
- watched state;
- resume;
- season-level actions;
- show-level actions;
- episode downloads;
- season downloads;
- complete-show downloads.

Playback should eventually support:

- automatic progression to the next episode;
- configurable next-episode countdown;
- intro skipping where supported;
- credit skipping where supported.

---

# 4. Sophisticated Video Playback

Integrated video playback is a major future engineering area.

Jellyfinity should eventually handle Jellyfin playback decisions involving:

- Direct Play;
- Direct Stream;
- transcoding;
- subtitle selection;
- subtitle burn-in where necessary;
- audio-stream selection;
- seeking;
- playback progress;
- watched state;
- application lifecycle;
- platform decoder differences;
- HDR where supported;
- codec compatibility.

External playback may exist as a fallback, but it is not the desired final experience.

---

# 5. Advanced Music Features

After basic playback is stable, music should expand toward a highly polished dedicated-player experience.

Desired features include:

- lyrics;
- synchronized lyrics;
- crossfade;
- ReplayGain and/or volume normalization;
- advanced queue behavior;
- richer recently played/history behavior;
- playlist creation/editing;
- improved discovery;
- high-quality album/artist presentation;
- configurable streaming quality for Wi-Fi and cellular;
- lossless/original playback where supported.

The goal is not to clone Spotify.

The goal is to reach the usability expectations Spotify has established while retaining Jellyfinity's own identity.

---

# 6. Playlists

Playlist management should become substantially better than the default Jellyfin experience.

Future capabilities may include:

- create playlist;
- rename;
- reorder tracks;
- remove tracks;
- add from context menus;
- bulk additions;
- offline playlist synchronization;
- artwork;
- duplicate handling;
- potentially smart/dynamic playlists if technically appropriate.

The product should make playlist curation enjoyable enough that users actually want to use it.

---

# 7. Social Sharing

A major future idea is shareable Jellyfinity media links.

The desired behavior:

1. User A shares a link to a song, album, movie, show, or other supported item.
2. User B opens the link in Jellyfinity.
3. Jellyfinity attempts to resolve the media against User B's own Jellyfin server.

This should ideally avoid requiring both users to share the same server.

## Portable Media Identity

Jellyfin item IDs are server-specific.

Future sharing may therefore need portable identity information such as:

- media type;
- title;
- artist;
- album;
- year;
- MusicBrainz identifiers where available;
- other stable metadata identifiers.

This requires a dedicated identity-resolution design.

It should not be implemented by casually passing Jellyfin item IDs around.

---

# 8. Collaborative Playlists

Collaborative playlists are a desired social feature.

They are substantially harder than simple share links because they introduce mutable shared state across users and potentially across independent Jellyfin servers.

Possible implementations may eventually require:

- a synchronization protocol;
- server-side support;
- an optional external Jellyfinity service;
- peer/shared document concepts;
- conflict resolution.

The privacy philosophy should be preserved.

This feature should only be designed once simpler playlist and sharing behavior is mature.

---

# 9. Home Customization

The Home experience should become modular.

Potential sections include:

- Continue Watching;
- Next Up;
- Continue Listening;
- Recently Played;
- Recently Added Movies;
- Recently Added Music;
- Recently Added Episodes;
- Favorite Albums;
- Favorite Artists;
- playlists;
- collections;
- recommendations;
- configurable library sections.

Users should eventually be able to:

- enable/disable modules;
- reorder modules;
- adjust presentation where appropriate.

Strong defaults remain mandatory.

---

# 10. Full Theme System

Jellyfinity should eventually expose deep UI customization directly in the application.

Potential theme properties include:

- accent colors;
- background colors;
- surfaces;
- text colors;
- typography;
- corner radii;
- spacing;
- gradients;
- transparency;
- card appearance;
- artwork treatment;
- navigation appearance;
- player appearance;
- content density.

Users should be able to save custom themes.

Jellyfinity should ship with curated themes.

A declarative import/export format should eventually allow community theme sharing without arbitrary CSS or executable theme code.

---

# 11. Feature Visibility and Layout Customization

Users should eventually be able to tailor Jellyfinity to their usage.

Examples:

- hide Movies;
- hide Shows;
- make Music primary;
- reorder Home sections;
- adjust grid/list density;
- choose poster/card sizes;
- alter navigation presentation where reasonable.

The initial goal is customization of existing UI, not a general-purpose UI builder.

---

# 12. Search Evolution

Search should evolve beyond the initial music-scoped implementation.

Possible final design:

- context-aware search when launched from Music/Movies/Shows;
- optional global search;
- explicit category switching;
- strongly separated result categories.

The product should avoid dumping actors, episodes, movies, songs, and unrelated entities into one noisy result list merely because names match.

---

# 13. Recommendations and Discovery

Discovery is useful, especially for music, but it should remain grounded in the user's own library.

Potential future features include:

- recommendations;
- recently played;
- related artists;
- similar albums;
- "because you listened to...";
- unwatched media suggestions;
- random picks;
- genre/decade discovery;
- library-based personalized Home sections.

Any recommendation system should be transparent enough to remain compatible with the privacy-first philosophy.

A proprietary tracking backend should not be introduced casually.

---

# 14. Multiple Server Improvements

Initial versions switch between active servers.

A major future version may explore **unified multi-server libraries**.

Example:

- Server A contains *Interstellar*;
- Server B contains *The Matrix*;
- Movies displays both in one combined library.

This is intentionally out of v1 scope.

It introduces difficult issues involving:

- identity;
- duplicate resolution;
- source preference;
- playback routing;
- search;
- synchronization;
- availability;
- watch state;
- server-specific permissions.

Architecture should avoid making this impossible, but no early release should implement large abstractions solely for this future possibility.

---

# 15. Multiple Users

Multiple saved users per server are required early.

Later versions may improve the experience with:

- fast profile switching;
- avatar/profile presentation;
- household-friendly switching;
- per-user local preferences;
- clearer boundaries between downloaded/private state.

---

# 16. Desktop

Windows and Linux clients are desirable later.

The desired desktop experience should resemble a genuine desktop media application rather than a stretched phone layout.

Potential goals include:

- Spotify-like persistent desktop layout;
- keyboard shortcuts;
- richer queue/library sidebars;
- drag-and-drop where useful;
- window-size-aware layouts;
- desktop media controls.

Desktop should be pursued once the mobile architecture and domain model are mature.

---

# 17. Android TV

Android TV is desirable but lower priority.

The existing Jellyfin Android TV experience is considered relatively acceptable, so Jellyfinity should first focus on areas with a larger usability gap.

If pursued later, Android TV should receive a genuine TV interaction model rather than merely reusing touch layouts.

---

# 18. Plugin / Extension System

A runtime plugin framework is not currently required.

The architecture should be modular enough that a future extension model is possible without a total rewrite.

However:

- no plugin API should be designed prematurely;
- mobile plugins introduce distribution/security complexity;
- plugin support should only exist if real contributor demand justifies it.

The first extensibility strategy is clean open-source modules and contributions to the core application.

---

# 19. Accessibility

Comprehensive accessibility work is not an initial differentiator but should become a serious future quality area.

Potential work includes:

- screen-reader semantics;
- scalable text;
- contrast auditing;
- reduced motion;
- large touch targets;
- keyboard navigation on desktop;
- focus management.

Early architecture should avoid knowingly making these impossible.

---

# 20. Advanced Onboarding

Onboarding should eventually feel as polished as the rest of the product.

Potential improvements include:

- welcome flow;
- server connection animations;
- helpful URL validation;
- profile selection;
- avatar presentation;
- first-sync progress;
- library setup/preferences;
- friendly actionable network troubleshooting.

The app should make connecting to a home server feel surprisingly simple.

---

# 21. Backward Jellyfin Compatibility

The initial minimum supported server version is:

> **Jellyfin 10.11.6**

Later releases may test and document compatibility with older Jellyfin versions.

Backward compatibility should be intentional and covered by a compatibility matrix.

It should not accumulate through undocumented hacks.

---

# 22. Broader Backend Support

Jellyfinity is a Jellyfin client.

Support for unrelated media backends is not currently a product objective.

The architecture may keep domain concepts reasonably independent of Jellyfin transport details, but no generic "supports everything" backend framework should be built without a real need.

---

# 23. Public Release and Distribution

Once Jellyfinity is stable enough, future work may include:

- Android distribution;
- iOS App Store distribution;
- reproducible release builds;
- signing/release automation;
- store metadata;
- screenshots;
- privacy declarations;
- crash-reporting decisions;
- public compatibility documentation;
- contributor/community processes.

Publishing should follow product readiness rather than dictate early architecture.

---

# 24. Long-Term Success

The long-term target is for Jellyfinity to become:

- the preferred daily client for its developer and initial users;
- a serious open-source alternative in the Jellyfin ecosystem;
- a project that contributors can extend confidently;
- a repository that demonstrates disciplined software engineering;
- a client whose self-hosted backend is almost invisible during normal use.
