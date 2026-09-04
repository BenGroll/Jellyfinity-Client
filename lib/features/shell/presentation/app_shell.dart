import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../../playback/presentation/MiniPlayer.dart';
import 'ShellDestination.dart';

/// The persistent frame around every authenticated screen: a body that
/// swaps per section, plus a bottom navigation bar.
///
/// Backed by go_router's [StatefulNavigationShell], so each section keeps
/// its own navigation stack and scroll position when the user switches
/// tabs. The bottom bar is only rendered once there are at least two
/// sections — with Home alone (v0.0.3) the shell is just the page, but the
/// structure is already in place.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goToBranch(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab again pops it back to its root.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showBar = shellDestinations.length > 1;

    return AppScaffold(
      padded: false,
      body: navigationShell,
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          if (showBar)
            _ShellNavigationBar(
              onSelected: _goToBranch,
              currentIndex: navigationShell.currentIndex,
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
