import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import '../../../design/design.dart';

/// Router fallback for a location that matches no route (a bad deep link, a
/// stale bookmark).
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.location});

  final String? location;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: EmptyStateView(
        icon: Icons.explore_off_rounded,
        title: 'Page not found',
        message: location == null
            ? 'That location doesn\'t exist.'
            : 'Nothing lives at $location.',
        actionLabel: 'Go home',
        onAction: () => context.go(RoutePaths.home),
      ),
    );
  }
}
