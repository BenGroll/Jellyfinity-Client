import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../design/design.dart';
import 'session/SessionCubit.dart';

/// The root widget.
///
/// Takes its router and session in via the constructor rather than reading
/// `getIt` itself, so widget tests can drive it with fakes. `main.dart`
/// resolves both from the composition root and passes them here.
///
/// Jellyfinity is dark-first (the "premium streaming app" intent in
/// `PHILOSOPHY.md`); a light theme is provided and a future settings screen
/// can expose [ThemeMode], but the shipped default is dark.
class JellyfinityApp extends StatelessWidget {
  const JellyfinityApp({
    super.key,
    required this.router,
    required this.session,
  });

  final GoRouter router;
  final SessionCubit session;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SessionCubit>.value(
      value: session,
      child: MaterialApp.router(
        title: 'Jellyfinity',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    );
  }
}
