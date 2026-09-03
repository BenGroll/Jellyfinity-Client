import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import '../../../design/design.dart';

/// Unauthenticated entry point: presents the product and starts the
/// connect-a-server flow.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                size: 64,
                color: t.colors.accent,
              ),
              SizedBox(height: t.spacing.lg),
              Text(
                'Jellyfinity',
                style: t.typography.displayLarge.copyWith(
                  color: t.colors.textPrimary,
                ),
              ),
              SizedBox(height: t.spacing.xs),
              Text(
                'Your server. Your media. A client that does not feel '
                'self-hosted.',
                textAlign: TextAlign.center,
                style: t.typography.bodyLarge.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
              SizedBox(height: t.spacing.xl),
              AppButton(
                label: 'Connect a server',
                icon: Icons.arrow_forward_rounded,
                expand: true,
                onPressed: () => context.pushNamed(RouteNames.connect),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
