import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';

/// One primary section of the app shell (a bottom-navigation destination
/// backed by its own navigator branch).
///
/// The list [shellDestinations] is the single source of truth for what the
/// shell contains: an entry here plus a case in `AppRouter` is a whole new
/// section, and the shell UI and navigation bar pick it up automatically.
/// v0.0.3 shipped Home alone; v0.0.8 added Music, which first made the
/// bottom bar appear; v0.0.10 renamed it to Library, scoped by whichever
/// media-type pill is active in `HomeLibraryHeader` (ADR-0014) — today
/// always Music. Movies and Shows arrive as pills, not new sections.
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
    path: RoutePaths.library,
    label: 'Library',
    icon: Icons.library_music_outlined,
    selectedIcon: Icons.library_music_rounded,
  ),
];
