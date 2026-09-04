import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../design/design.dart';
import 'playback/PlaybackCubit.dart';
import 'session/SessionCubit.dart';

/// The root widget.
///
/// Takes its router, session and playback in via the constructor rather
/// than reading `getIt` itself, so widget tests can drive it with fakes.
/// `main.dart` resolves all three from the composition root and passes
/// them here. [PlaybackCubit] sits at this level — the same as
/// [SessionCubit] — because it is cross-cutting app state: the shell's
/// mini-player, Now Playing and the queue screen all need it regardless
/// of which tab is active.
///
/// Jellyfinity is dark-first (the "premium streaming app" intent in
/// `PHILOSOPHY.md`); a light theme is provided and a future settings screen
/// can expose [ThemeMode], but the shipped default is dark.
class JellyfinityApp extends StatelessWidget {
  const JellyfinityApp({
    super.key,
    required this.router,
    required this.session,
    required this.playback,
  });

  final GoRouter router;
  final SessionCubit session;
  final PlaybackCubit playback;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SessionCubit>.value(value: session),
        BlocProvider<PlaybackCubit>.value(value: playback),
      ],
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
