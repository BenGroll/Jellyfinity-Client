import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import '../../../design/design.dart';

/// The Home section.
///
/// Still deliberately small: a modular, customisable Home is `OUTLOOK.md`
/// §9's, not this release's. v0.0.8 puts the actual library one tap away
/// in the Library section, and Home says so rather than pretending to be a
/// dashboard. Its own title bar is gone as of ADR-0014 —
/// `HomeLibraryHeader` (shared across every shell tab) replaces it, and
/// account access moved to the sidebar.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music_outlined, size: 40, color: t.colors.accent),
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
            'Your music library is in the Library tab. Movies and shows '
            'follow in a later release.',
            textAlign: TextAlign.center,
            style: t.typography.bodyMedium.copyWith(
              color: t.colors.textSecondary,
            ),
          ),
          SizedBox(height: t.spacing.lg),
          AppButton(
            label: 'Browse music',
            icon: Icons.library_music_rounded,
            onPressed: () => context.goNamed(RouteNames.library),
          ),
        ],
      ),
    );
  }
}
