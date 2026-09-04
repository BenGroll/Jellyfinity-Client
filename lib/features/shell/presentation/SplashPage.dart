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
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: t.colors.accent,
          ),
        ),
      ),
    );
  }
}
