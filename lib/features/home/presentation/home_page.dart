import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import '../../../design/design.dart';

/// The Home section — the first and, for now, only shell destination.
///
/// There is no library to show yet (media arrives from v0.0.7 on), so this
/// is a deliberately small real screen rather than a stubbed-out future
/// section. It exists to exercise the shell, the page scaffold, and the
/// shared primitives end to end.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppScaffold(
      title: 'Home',
      actions: [
        IconButton(
          onPressed: () => context.pushNamed(RouteNames.accounts),
          icon: const Icon(Icons.account_circle_outlined),
          tooltip: 'Accounts',
        ),
      ],
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 40,
              color: t.colors.accent,
            ),
            SizedBox(height: t.spacing.md),
            Text(
              'Your media, made to feel effortless',
              textAlign: TextAlign.center,
              style: t.typography.titleLarge.copyWith(
                color: t.colors.textPrimary,
              ),
            ),
            SizedBox(height: t.spacing.xs),
            Text(
              'Music, movies, and shows will appear here as the library '
              'features land.',
              textAlign: TextAlign.center,
              style: t.typography.bodyMedium.copyWith(
                color: t.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
