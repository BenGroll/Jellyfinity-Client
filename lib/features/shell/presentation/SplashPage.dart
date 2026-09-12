import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// Shown only while [SessionStatus.unknown] — i.e. while a saved session is
/// being restored at startup.
///
/// Not reachable in v0.0.3 (the stub session never sits in `unknown`); it
/// exists so the router already has a defined destination for that window
/// when session restore is implemented in v0.0.5.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppScaffold(
      padded: false,
      body: ColoredBox(
        key: const Key('splash-background'),
        color: t.colors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFF3FD8),
                    Color(0xFF7A5CFF),
                    Color(0xFF16E1FF),
                  ],
                ).createShader(bounds),
                child: const Icon(
                  Icons.all_inclusive_rounded,
                  key: Key('splash-logo'),
                  size: 112,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: t.spacing.md),
              Text(
                'Jellyfinity',
                style: t.typography.headlineLarge.copyWith(
                  color: t.colors.textPrimary,
                ),
              ),
              SizedBox(height: t.spacing.lg),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: t.colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
