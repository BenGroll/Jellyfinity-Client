import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/platform/television_mode.dart';
import '../../../design/design.dart';
import '../../music/presentation/search/InlineMusicSearch.dart';
import '../../playback/presentation/MiniPlayer.dart';
import 'AppSidebar.dart';
import 'HomeLibraryHeader.dart';
import 'ShellDestination.dart';
import 'TelevisionNavigationRail.dart';

/// The persistent frame around every authenticated screen: a shared header
/// (search + media-type pills), a body that swaps per section, a
/// mini-player, and a bottom navigation bar.
///
/// Backed by go_router's [StatefulNavigationShell], so each section keeps
/// its own navigation stack and scroll position when the user switches
/// tabs. The bottom bar is only rendered once there are at least two
/// sections — with Home alone (v0.0.3) the shell is just the page, but the
/// structure is already in place.
///
/// Search is inline (ADR-0014), not a pushed page: activating it swaps the
/// header out for [InlineMusicSearch] in place, so the bottom nav and
/// mini-player stay put underneath it — this is presentation state local
/// to the shell, not a route.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _searching = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _startSearch() => setState(() => _searching = true);
  void _stopSearch() => setState(() => _searching = false);
  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  void _goToBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      // Tapping the active tab again pops it back to its root.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showBar = shellDestinations.length > 1;
    final location = GoRouterState.of(context).uri.path;
    final isDetail =
        location.contains('/artist/') ||
        location.contains('/album/') ||
        location.contains('/playlist/');

    final television = TelevisionModeScope.of(context);
    final mainContent = Column(
      children: [
        if (!_searching && !isDetail)
          HomeLibraryHeader(onSearchTap: _startSearch, onMenuTap: _openMenu),
        Expanded(
          child: _searching
              ? InlineMusicSearch(onClose: _stopSearch)
              : widget.navigationShell,
        ),
      ],
    );

    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searching) _stopSearch();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              _startSearch,
          if (_searching)
            const SingleActivator(LogicalKeyboardKey.escape): _stopSearch,
          if (television)
            const SingleActivator(LogicalKeyboardKey.contextMenu): _openMenu,
          if (television)
            if (_searching)
              const SingleActivator(LogicalKeyboardKey.browserBack):
                  _stopSearch,
          if (_searching)
            const SingleActivator(LogicalKeyboardKey.goBack): _stopSearch,
          const SingleActivator(LogicalKeyboardKey.mediaTopMenu): _openMenu,
          if (television)
            const SingleActivator(LogicalKeyboardKey.gameButtonStart):
                _openMenu,
        },
        child: FocusScope(
          autofocus: true,
          child: AppScaffold(
            scaffoldKey: _scaffoldKey,
            padded: false,
            drawer: const AppSidebar(),
            body: SafeArea(
              bottom: false,
              child: television
                  ? Row(
                      key: const Key('television-navigation'),
                      children: [
                        TelevisionNavigationRail(
                          currentIndex: widget.navigationShell.currentIndex,
                          onSelected: _goToBranch,
                        ),
                        VerticalDivider(
                          width: 1,
                          color: context.tokens.colors.border,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: mainContent),
                              const MiniPlayer(),
                            ],
                          ),
                        ),
                      ],
                    )
                  : mainContent,
            ),
            bottomBar: television
                ? null
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MiniPlayer(),
                      if (showBar)
                        _ShellNavigationBar(
                          onSelected: _goToBranch,
                          currentIndex: widget.navigationShell.currentIndex,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ShellNavigationBar extends StatelessWidget {
  const _ShellNavigationBar({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.colors.surface.withValues(alpha: .32),
        border: Border(top: BorderSide(color: t.colors.border)),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        selectedIndex: currentIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final d in shellDestinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
