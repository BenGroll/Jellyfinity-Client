import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';

/// One primary section of the app shell (a bottom-navigation destination
/// backed by its own navigator branch).
///
/// The list [shellDestinations] is the single source of truth for what the
/// shell contains. v0.0.3 ships only Home; adding Music/Movies/Shows/
/// Library later is an entry here plus a branch in the router — the shell
/// UI and the navigation bar pick them up automatically.
class ShellDestination {
  const ShellDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<ShellDestination> shellDestinations = [
  ShellDestination(
    path: RoutePaths.home,
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
];
