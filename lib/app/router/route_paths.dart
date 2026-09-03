/// Every route location and name in one place.
///
/// Features refer to `RoutePaths.home` / `RouteNames.home`, never string
/// literals, so routes can be renamed or reorganised without hunting
/// through call sites. Deep-link handling (a later milestone) also starts
/// from this list.
abstract final class RoutePaths {
  /// Shown while a saved session is being restored (v0.0.5+).
  static const splash = '/splash';

  /// Unauthenticated entry point: connect a server / sign in.
  static const welcome = '/welcome';

  // Shell sections.
  static const home = '/home';

  /// Fallback for an unmatched location.
  static const notFound = '/404';
}

abstract final class RouteNames {
  static const splash = 'splash';
  static const welcome = 'welcome';
  static const home = 'home';
  static const notFound = 'notFound';
}
