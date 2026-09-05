import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../../features/auth/presentation/accounts/accounts_page.dart';
import '../../features/auth/presentation/login/login_page.dart';
import '../../features/auth/presentation/server_setup/server_setup_page.dart';
import '../../features/downloads/presentation/DownloadsPage.dart';
import '../../features/home/presentation/HomePage.dart';
import '../../features/music/presentation/detail/AlbumDetailPage.dart';
import '../../features/music/presentation/detail/ArtistDetailPage.dart';
import '../../features/music/presentation/detail/PlaylistDetailPage.dart';
import '../../features/music/presentation/library/LibraryPage.dart';
import '../../features/music/presentation/search/music_search_cubit.dart';
import '../../features/music/presentation/search/SearchCategoryPage.dart';
import '../../features/onboarding/presentation/WelcomePage.dart';
import '../../features/playback/presentation/LyricsPage.dart';
import '../../features/playback/presentation/NowPlayingPage.dart';
import '../../features/playback/presentation/QueuePage.dart';
import '../../features/settings/presentation/SettingsPage.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shell/presentation/NotFoundPage.dart';
import '../../features/shell/presentation/ShellDestination.dart';
import '../../features/shell/presentation/SplashPage.dart';
import '../../domain/media/MediaId.dart';
import '../../infrastructure/jellyfin/server/JellyfinServerInfo.dart';
import '../session/SessionCubit.dart';
import '../session/session_status.dart';
import 'GoRouterRefreshStream.dart';
import 'route_paths.dart';

/// Owns the app's [GoRouter].
///
/// This is a composition-root object (it wires features together and is the
/// one place `getIt` is read for navigation), so it lives in `lib/app`, not
/// in a feature. It:
///
/// - builds the shell branches from [shellDestinations], so new sections
///   are one list entry plus one `path → page` case below, plus their
///   sub-routes in [_subRoutesFor];
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
        GoRoute(
          path: RoutePaths.settings,
          name: RouteNames.settings,
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: RoutePaths.downloads,
          name: RouteNames.downloads,
          builder: (context, state) => const DownloadsPage(),
        ),
        GoRoute(
          path: RoutePaths.nowPlaying,
          name: RouteNames.nowPlaying,
          builder: (context, state) => const NowPlayingPage(),
          routes: [
            GoRoute(
              path: RoutePaths.nowPlayingQueue,
              name: RouteNames.nowPlayingQueue,
              builder: (context, state) => const QueuePage(),
            ),
            GoRoute(
              path: RoutePaths.nowPlayingLyrics,
              name: RouteNames.nowPlayingLyrics,
              builder: (context, state) => const LyricsPage(),
            ),
          ],
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
                    // Sub-routes of a section live inside its branch, so
                    // opening an album keeps the bottom bar and the
                    // section's own back stack.
                    routes: _subRoutesFor(destination.path),
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
        // Signed in: the splash, the product intro, and a completed
        // sign-in have nothing left to do, so they fall through to the
        // shell. /connect stays reachable so "add another account" works
        // from the Accounts screen; everything else is allowed.
        const settled = {
          RoutePaths.splash,
          RoutePaths.welcome,
          RoutePaths.signIn,
        };
        return settled.contains(location) ? RoutePaths.home : null;
    }
  }

  static String _routeNameFor(String path) => switch (path) {
    RoutePaths.home => RouteNames.home,
    RoutePaths.library => RouteNames.library,
    _ => path,
  };

  static Widget _pageFor(String path) => switch (path) {
    RoutePaths.home => const HomePage(),
    RoutePaths.library => const LibraryPage(),
    _ => NotFoundPage(location: path),
  };

  static List<RouteBase> _subRoutesFor(String path) => switch (path) {
    RoutePaths.library => _libraryRoutes,
    _ => const [],
  };

  /// Everything reachable from the Library section. Search itself is
  /// inline in the shared header (ADR-0014), not a route — only its
  /// "show all in one category" drill-down is.
  ///
  /// Each detail route takes a `MediaId.key` — server and item together.
  /// A key that cannot be parsed is a stale or hand-written link, and
  /// lands on the not-found page instead of throwing.
  static final List<RouteBase> _libraryRoutes = [
    GoRoute(
      path: RoutePaths.librarySearchCategory,
      name: RouteNames.librarySearchCategory,
      builder: (context, state) {
        final category = SearchCategory.tryParse(
          state.pathParameters['category'] ?? '',
        );
        final query = state.uri.queryParameters['q'] ?? '';
        if (category == null || query.isEmpty) {
          return const LibraryPage();
        }
        return SearchCategoryPage(category: category, query: query);
      },
    ),
    GoRoute(
      path: RoutePaths.libraryArtist,
      name: RouteNames.libraryArtist,
      builder: (context, state) =>
          _withMediaId(state, (id) => ArtistDetailPage(artistId: id)),
    ),
    GoRoute(
      path: RoutePaths.libraryAlbum,
      name: RouteNames.libraryAlbum,
      builder: (context, state) =>
          _withMediaId(state, (id) => AlbumDetailPage(albumId: id)),
    ),
    GoRoute(
      path: RoutePaths.libraryPlaylist,
      name: RouteNames.libraryPlaylist,
      builder: (context, state) =>
          _withMediaId(state, (id) => PlaylistDetailPage(playlistId: id)),
    ),
  ];

  static Widget _withMediaId(
    GoRouterState state,
    Widget Function(MediaId id) build,
  ) {
    final id = MediaId.tryParse(state.pathParameters['id'] ?? '');
    if (id == null) return NotFoundPage(location: state.uri.toString());
    return build(id);
  }
}
