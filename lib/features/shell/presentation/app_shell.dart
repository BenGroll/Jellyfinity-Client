import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../../music/presentation/search/InlineMusicSearch.dart';
import '../../playback/presentation/MiniPlayer.dart';
import 'AppSidebar.dart';
import 'HomeLibraryHeader.dart';
import 'ShellDestination.dart';

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

  void _startSearch() => setState(() => _searching = true);
  void _stopSearch() => setState(() => _searching = false);

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

    return AppScaffold(
      padded: false,
      drawer: const AppSidebar(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!_searching) HomeLibraryHeader(onSearchTap: _startSearch),
            Expanded(
              child: _searching
                  ? InlineMusicSearch(onClose: _stopSearch)
                  : widget.navigationShell,
            ),
          ],
        ),
      ),
      bottomBar: Column(
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
        color: t.colors.surface,
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
