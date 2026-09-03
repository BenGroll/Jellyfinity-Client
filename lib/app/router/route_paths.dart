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

  /// Saved servers & profiles: switch active profile, sign out, remove.
  static const accounts = '/accounts';

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
  static const accounts = 'accounts';
  static const notFound = 'notFound';
}
