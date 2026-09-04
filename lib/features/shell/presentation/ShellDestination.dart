import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';

/// One primary section of the app shell (a bottom-navigation destination
/// backed by its own navigator branch).
///
/// The list [shellDestinations] is the single source of truth for what the
/// shell contains: an entry here plus a case in `AppRouter` is a whole new
/// section, and the shell UI and navigation bar pick it up automatically.
/// v0.0.3 shipped Home alone; v0.0.8 adds Music, which is what first makes
/// the bottom bar appear. Movies and Shows follow the same way.
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
  ShellDestination(
    path: RoutePaths.music,
    label: 'Music',
    icon: Icons.library_music_outlined,
    selectedIcon: Icons.library_music_rounded,
  ),
];
