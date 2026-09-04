/// Every route location and name in one place.
///
/// Features refer to `RoutePaths.home` / `RouteNames.home`, never string
/// literals, so routes can be renamed or reorganised without hunting
/// through call sites. Deep-link handling (a later milestone) also starts
/// from this list.
abstract final class RoutePaths {
  /// Shown while a saved session is being restored at startup.
  static const splash = '/splash';

  // Onboarding / sign-in flow (unauthenticated, plus "add another
  // account" while signed in).
  /// Product intro; entry point to connecting a server.
  static const welcome = '/welcome';

  /// Enter and validate a Jellyfin server address.
  static const connect = '/connect';

  /// Enter Jellyfin credentials for a validated server.
  static const signIn = '/connect/sign-in';

  // Shell sections.
  static const home = '/home';

  /// The library: whichever media type is active in the media-pills
  /// header (today, always Music — artists, albums, songs and
  /// playlists). Search is no longer a subscreen of this (ADR-0014); it
  /// lives inline in the shared header instead.
  static const library = '/library';

  // Library sub-routes. Each is a child of [library], so opening an album
  // keeps the bottom navigation and the section's own back stack.
  /// One category of search results in full:
  /// `/library/search/albums?q=blue`.
  static const librarySearchCategory = 'search/:category';

  /// One artist. The `:id` is a `MediaId.key` — server and item together,
  /// because an item id alone does not identify anything.
  static const libraryArtist = 'artist/:id';
  static const libraryAlbum = 'album/:id';
  static const libraryPlaylist = 'playlist/:id';

  /// Saved servers & profiles: switch active profile, sign out, remove.
  static const accounts = '/accounts';

  /// App preferences, reached from the sidebar.
  static const settings = '/settings';

  /// The full player screen. A root route, not nested under a shell
  /// branch: it is reachable from any tab and covers the bottom nav.
  static const nowPlaying = '/now-playing';

  /// The queue screen, a child of [nowPlaying].
  static const nowPlayingQueue = 'queue';

  /// Fallback for an unmatched location.
  static const notFound = '/404';

  /// Locations that make up the onboarding / add-account flow.
  static const onboarding = {welcome, connect, signIn};
}

abstract final class RouteNames {
  static const splash = 'splash';
  static const welcome = 'welcome';
  static const connect = 'connect';
  static const signIn = 'signIn';
  static const home = 'home';
  static const library = 'library';
  static const librarySearchCategory = 'librarySearchCategory';
  static const libraryArtist = 'libraryArtist';
  static const libraryAlbum = 'libraryAlbum';
  static const libraryPlaylist = 'libraryPlaylist';
  static const accounts = 'accounts';
  static const settings = 'settings';
  static const nowPlaying = 'nowPlaying';
  static const nowPlayingQueue = 'nowPlayingQueue';
  static const notFound = 'notFound';
}
