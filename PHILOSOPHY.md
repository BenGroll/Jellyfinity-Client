# Jellyfinity Philosophy

## Purpose

Jellyfinity is a free and open-source Jellyfin client designed to make self-hosted media feel like a premium streaming service.

The server may be technical infrastructure. The client should not feel like infrastructure.

Jellyfinity should feel deliberate, polished, trustworthy, responsive, and pleasant enough that users choose it because it is the best client for them—not merely because it connects to their own server.

Its central product promise is:

> **Your server. Your media. A client that does not feel self-hosted.**

---

## 1. Product Identity

Jellyfinity is a first-class client for:

- music;
- movies;
- television.

Music receives especially strong attention. It must not feel like an auxiliary feature attached to a video client.

The music experience should eventually compete with the usability expectations created by products such as Spotify and SoundCloud, while movies and television should feel equally native to the same application.

Jellyfinity is not intended to expose every Jellyfin feature.

It is a media consumption application. Server administration, plugin management, user administration, metadata administration, library scans, server logs, and similar functionality belong elsewhere.

The product should favor depth and quality over checkbox-driven feature count.

---

## 2. The UX Contract: Never Leave the User Guessing

One of Jellyfinity's most important rules is:

> **Never leave the user guessing.**

The user should be able to understand what the application is doing and what state their media is in.

The UI must distinguish between states such as:

- loading;
- partially loaded;
- loaded;
- empty;
- refreshing;
- offline;
- cached;
- unavailable;
- unauthorized;
- failed;
- retrying;
- downloading;
- downloaded;
- local-only.

A generic spinner on an otherwise empty page is not an acceptable default loading experience.

Where possible, Jellyfinity should:

- navigate immediately to the expected destination;
- render the known structure of the destination before all data is available;
- use skeleton layouts;
- preserve already-loaded content during temporary failures;
- progressively load artwork and secondary metadata;
- give immediate interaction feedback;
- use optimistic updates when safe;
- communicate errors locally instead of invalidating entire screens;
- provide useful recovery actions;
- make unavailable media visibly unavailable before playback is attempted when possible.

If an album contains twelve tracks and one cannot be played, the album should still exist as an album with eleven usable tracks and one clearly marked unavailable track.

Partial success is preferable to unnecessary total failure.

---

## 3. Premium Is a Functional Requirement

Polish is not a final design phase.

Perceived reliability, feedback, animation, loading behavior, caching, transitions, state handling, and error communication are part of the feature itself.

A feature is not considered complete merely because the API request succeeds.

A completed feature should account for its relevant lifecycle states, including:

- initial;
- loading;
- success;
- empty;
- partial success;
- offline;
- cached;
- failure;
- retry;
- cancellation;
- application restart where relevant.

The application should feel solid even when the network is not.

---

## 4. Media Should Feel Owned, Not Borrowed

Jellyfinity should preserve the benefits of self-hosting:

- privacy;
- ownership;
- independence;
- no advertising;
- no subscription tiers;
- no deliberate vendor lock-in;
- no sale of user data;
- no unnecessary cloud dependency.

The application should communicate directly with the user's infrastructure wherever practical.

If analytics, telemetry, or crash reporting are ever introduced, they must respect data minimization, transparency, consent, and the project's open-source philosophy.

---

## 5. Offline Is Media Availability, Not a Separate Application Mode

Offline support is a core architectural concern.

Jellyfinity should not think in terms of a completely separate "offline mode" UI.

Instead, media has availability.

Examples include:

- remote only;
- local and remote;
- local only;
- remote currently unavailable;
- partially available.

The same album, movie, show, or playlist should remain the same conceptual entity whether it is streamed from the server, loaded from local metadata, or played from a local download.

Downloaded content becomes first-class local media.

If a downloaded item later disappears from the Jellyfin server, Jellyfinity should preserve the local copy unless the user or an explicit cleanup policy removes it.

Such content should be clearly identified as something like **Only on Device**.

The application should display as much useful cached or local information as possible when the server cannot be reached.

---

## 6. Music Is First-Class

Music is a major differentiator of Jellyfinity.

The application should eventually provide a robust music experience with:

- artists;
- albums;
- songs;
- playlists;
- favorites;
- queue management;
- persistent playback;
- background playback;
- system media controls;
- lyrics;
- synchronized lyrics where available;
- gapless playback;
- crossfade;
- ReplayGain and/or volume normalization where technically feasible;
- configurable playback quality;
- offline playback;
- playlist creation and editing;
- collaboration features in later versions.

The queue is application state, not merely state hidden inside the playback library.

A queue should survive application restarts where practical and support reordering, removing, clearing, Play Next, Add to Queue, shuffle, repeat, and useful distinction between manually queued and automatically upcoming media.

Gapless playback is a particularly important requirement.

---

## 7. Movies and Television Are Equally Native

Movies and television are not secondary plugins to the music experience.

The eventual application should provide strong experiences for:

- movie browsing;
- movie detail pages;
- Continue Watching;
- television shows;
- seasons;
- episodes;
- Next Up;
- resume;
- watched state;
- automatic next-episode playback;
- configurable countdowns;
- intro skipping where supported;
- credit skipping where supported;
- offline downloads for movies, episodes, seasons, and complete shows.

The exact movie-detail and television UX can evolve through implementation and design work.

---

## 8. Search Should Respect Context

Search should not overwhelm users with technically matching but contextually weak results.

Jellyfinity should eventually support an intentionally designed search model that may combine:

- context-aware search;
- selectable search scopes;
- category-separated global search.

For example, search initiated from Music may search or heavily prioritize artists, albums, songs, and playlists rather than actors, individual television episodes, and unrelated metadata.

Search should optimize for what the user likely means, not merely for everything the server can return.

---

## 9. Customization Is a Product Feature

Customization should be deep, safe, and approachable.

Users should not need custom CSS, patched builds, or unofficial modifications to significantly personalize the application.

Jellyfinity should eventually support customization of areas such as:

- accent colors;
- backgrounds;
- surfaces;
- typography;
- corner radii;
- spacing;
- gradients;
- artwork treatment;
- navigation appearance;
- player appearance;
- card sizing;
- content density;
- grid/list presentation;
- Home modules;
- Home module ordering;
- feature visibility.

Customization should be implemented through a structured design-token and theme system.

Themes should eventually be serializable, exportable, importable, and shareable without executing arbitrary code.

Jellyfinity should still ship with excellent defaults.

Customization must never become an excuse for poor default design.

---

## 10. Cross-Platform Philosophy

Android and iOS are the primary platforms.

The application should maintain one recognizable Jellyfinity identity while respecting the interaction patterns users expect on each platform.

Platform adaptation may include:

- back gestures;
- navigation behavior;
- haptics;
- context menus;
- keyboard behavior;
- notifications;
- system media sessions;
- system share sheets;
- background execution rules.

The goal is not pixel-identical behavior at the expense of platform usability.

Future targets may include Windows, Linux, and Android TV, but they are not part of the initial delivery target.

---

## 11. Scale Is Normal

Large personal libraries are not edge cases.

The real development server contains roughly:

- 130,000 songs;
- 500 movies;
- 4,000 television episodes.

Jellyfinity should remain comfortable at this scale and should react intelligently to much larger libraries.

No important architecture should assume that an entire library can be fetched, decoded, stored, or filtered in memory at once.

The application should use techniques such as:

- pagination;
- incremental loading;
- virtualized lists;
- server-side filtering;
- indexed local persistence;
- bounded caches;
- lazy loading;
- background synchronization.

---

## 12. Clear Domain Boundaries

Jellyfinity is a Jellyfin client, but Jellyfin API response models should not become the entire application's domain vocabulary.

The project should distinguish where useful between:

- Jellyfin API models;
- Jellyfinity domain models;
- presentation state;
- persistence representations.

The UI should not directly depend on raw Jellyfin JSON or transport models.

A typical direction should resemble:

```text
UI
 ↓
Presentation
 ↓
Domain / Repository Contracts
 ↑
Infrastructure Implementations
```

Infrastructure may include:

- Jellyfin networking;
- local database;
- secure storage;
- playback engines;
- platform APIs.

The architecture should support local and remote sources without forcing the UI to know where each value came from.

---

## 13. Feature-First, Not Folder-First

The repository should be structured so contributors can understand one feature without loading the whole application into their head.

The project should prefer feature-oriented modularity over global buckets such as:

```text
controllers/
models/
views/
repositories/
```

Shared concepts should be extracted when they genuinely span multiple features.

Architecture should help contributors reason locally.

It should not create abstraction solely for architectural purity.

---

## 14. Dependencies Must Earn Their Place

Jellyfinity should not reinvent labor-intensive infrastructure simply for ideological purity.

Dependencies are appropriate when they remove substantial non-differentiating work, especially for:

- media playback;
- networking;
- local database infrastructure;
- secure credential storage;
- platform integrations.

At the same time, trivial application logic should not gain a dependency merely to save a few lines of code.

Dependencies should be evaluated for:

- maintenance activity;
- platform support;
- license compatibility;
- API stability;
- security;
- binary size;
- transitive dependency cost;
- testability;
- replaceability.

Important dependency decisions should be documented through ADRs.

---

## 15. Test-Driven Development

Jellyfinity should primarily use test-driven development where it provides meaningful value.

Tests should focus on behavior and contracts rather than implementation trivia.

High-value test areas include:

- domain logic;
- queue behavior;
- repositories;
- authentication/session behavior;
- synchronization;
- caching;
- download state;
- playback state;
- error handling;
- theme serialization;
- Jellyfin model mapping.

Widget tests should cover important UI states and interactions.

Integration tests should cover critical user journeys.

A high coverage number alone is not a success criterion.

Confidence is.

---

## 16. Open-Source Engineering Is Part of the Product

Jellyfinity should be maintained as though it were a professional collaborative software project even while it is primarily developed as a hobby project.

The repository should demonstrate:

- meaningful commits;
- feature branches;
- pull-request-based integration;
- automated formatting;
- static analysis;
- tests;
- CI;
- contribution guidelines;
- issue templates;
- pull request templates;
- changelogs;
- semantic releases;
- documented architecture;
- reproducible environments;
- clean dependency management.

The history of the project should be understandable.

The repository should be a credible example of professional software-engineering practice.

---

## 17. Architecture Decisions Should Be Explainable

Important architectural choices should be recorded using lightweight Architecture Decision Records.

An ADR should usually contain:

- context;
- considered options;
- decision;
- reasoning;
- consequences.

Likely ADR topics include:

- project structure;
- state management;
- dependency injection;
- routing;
- local database;
- Jellyfin API integration;
- authentication/session handling;
- offline architecture;
- media playback engine;
- queue ownership;
- download architecture;
- theming;
- dependency policy.

ADRs should be concise enough that both humans and development agents can retrieve the reasoning behind a decision without needing the entire project history.

---

## 18. Scope Discipline

Jellyfinity has a broad long-term product scope.

Individual releases should be narrow.

The project should prefer complete vertical slices over wide collections of half-finished features.

When choosing between implementing another feature and making an existing core feature substantially better, Jellyfinity should usually choose the latter.

The product may eventually become large.

Each release should remain understandable.

---

## 19. Definition of Success

Jellyfinity succeeds first when its developer and the people already using the associated Jellyfin server prefer it for everyday use over available alternatives.

A second objective is for Jellyfinity to mature into a serious open-source Jellyfin client.

A third objective is for the repository itself to demonstrate strong, practical software-engineering skill.

Stars, downloads, and contributor counts are welcome outcomes.

They are not the primary measure of success.
