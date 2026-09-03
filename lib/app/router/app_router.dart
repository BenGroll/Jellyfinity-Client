import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../../features/auth/presentation/accounts/accounts_page.dart';
import '../../features/auth/presentation/login/login_page.dart';
import '../../features/auth/presentation/server_setup/server_setup_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/onboarding/presentation/welcome_page.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shell/presentation/not_found_page.dart';
import '../../features/shell/presentation/shell_destination.dart';
import '../../features/shell/presentation/splash_page.dart';
import '../../infrastructure/jellyfin/server/jellyfin_server_info.dart';
import '../session/session_cubit.dart';
import '../session/session_status.dart';
import 'go_router_refresh_stream.dart';
import 'route_paths.dart';

/// Owns the app's [GoRouter].
///
/// This is a composition-root object (it wires features together and is the
/// one place `getIt` is read for navigation), so it lives in `lib/app`, not
/// in a feature. It:
///
/// - builds the shell branches from [shellDestinations], so new sections
///   are one list entry plus one `path → page` case below;
/// - re-runs [_redirect] whenever [SessionCubit] emits, via
///   [GoRouterRefreshStream];
/// - gates the onboarding flow vs. the shell on [SessionStatus].
@lazySingleton
class AppRouter {
  AppRouter(this._session) {
    _config = _build();
  }

  final SessionCubit _session;
  late final GoRouter _config;

  final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );

  GoRouter get config => _config;

  GoRouter _build() {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: RoutePaths.home,
      refreshListenable: GoRouterRefreshStream(_session.stream),
      redirect: _redirect,
      errorBuilder: (context, state) =>
          NotFoundPage(location: state.uri.toString()),
      routes: [
        GoRoute(
          path: RoutePaths.splash,
          name: RouteNames.splash,
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: RoutePaths.welcome,
          name: RouteNames.welcome,
          builder: (context, state) => const WelcomePage(),
        ),
        GoRoute(
          path: RoutePaths.connect,
          name: RouteNames.connect,
          builder: (context, state) => const ServerSetupPage(),
        ),
        GoRoute(
          path: RoutePaths.signIn,
          name: RouteNames.signIn,
          builder: (context, state) {
            final server = state.extra;
            if (server is! JellyfinServerInfo) {
              // Reached without a validated server (e.g. a manual deep
              // link) — send the user back to enter an address.
              return const ServerSetupPage();
            }
            return LoginPage(server: server);
          },
        ),
        GoRoute(
          path: RoutePaths.accounts,
          name: RouteNames.accounts,
          builder: (context, state) => const AccountsPage(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            for (final destination in shellDestinations)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: destination.path,
                    name: _routeNameFor(destination.path),
                    builder: (context, state) => _pageFor(destination.path),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  String? _redirect(BuildContext context, GoRouterState state) {
    final status = _session.status;
    final location = state.matchedLocation;
    final inOnboarding = RoutePaths.onboarding.contains(location);

    switch (status) {
      case SessionStatus.unknown:
        return location == RoutePaths.splash ? null : RoutePaths.splash;
      case SessionStatus.unauthenticated:
        return inOnboarding ? null : RoutePaths.welcome;
      case SessionStatus.authenticated:
        // Signed in: the splash and the product intro have nothing left
        // to do; everything else (shell, account switcher, and the
        // add-another-account flow) is allowed.
        if (location == RoutePaths.splash || location == RoutePaths.welcome) {
          return RoutePaths.home;
        }
        return null;
    }
  }

  static String _routeNameFor(String path) => switch (path) {
    RoutePaths.home => RouteNames.home,
    _ => path,
  };

  static Widget _pageFor(String path) => switch (path) {
    RoutePaths.home => const HomePage(),
    _ => NotFoundPage(location: path),
  };
}
