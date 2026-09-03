import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/session/session_cubit.dart';
import '../../../design/design.dart';

/// Unauthenticated entry point.
///
/// The real "add a server, sign in" flow is the authentication milestone
/// (v0.0.5). For now this screen just presents the product and offers a
/// single development action that flips [SessionCubit] to authenticated, so
/// the authenticated navigation tree is reachable and the router's auth
/// gate has both sides to exercise.
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
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                expand: true,
                onPressed: () =>
                    context.read<SessionCubit>().signInForDevelopment(),
              ),
              SizedBox(height: t.spacing.sm),
              Text(
                'Server setup and sign-in arrive in a later milestone.',
                textAlign: TextAlign.center,
                style: t.typography.caption.copyWith(
                  color: t.colors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
