import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../design/design.dart';
import '../design/components/ArtworkBackdropScope.dart';
import '../domain/media/MediaImage.dart';
import '../features/music/presentation/widgets/ArtworkBackground.dart';
import 'playback/PlaybackUiState.dart';
import 'connectivity/OfflineCubit.dart';
import 'DesktopScrollBehavior.dart';
import 'downloads/DownloadsCubit.dart';
import 'favorites/FavoritesRevisionCubit.dart';
import 'navigation/MediaScopeCubit.dart';
import 'playback/PlaybackCubit.dart';
import 'session/SessionCubit.dart';
import 'settings/SettingsCubit.dart';

/// The root widget.
///
/// Takes its router, session, playback, settings and media scope in via the
/// constructor rather than reading `getIt` itself, so widget tests can
/// drive it with fakes. `main.dart` resolves all of them from the
/// composition root and passes them here. [PlaybackCubit] sits at this
/// level — the same as [SessionCubit] — because it is cross-cutting app
/// state: the shell's mini-player, Now Playing and the queue screen all
/// need it regardless of which tab is active. [SettingsCubit] and
/// [MediaScopeCubit] join it for the same reason (ADR-0014): the shared
/// header and sidebar read them from every tab, and [DownloadsCubit]
/// for the same reason again (ADR-0020): a track row, an album header
/// and the queue all show the same download state.
///
/// Jellyfinity is dark-first (the "premium streaming app" intent in
/// `PHILOSOPHY.md`); a light theme is provided and a future settings
/// screen can expose [ThemeMode], but the shipped default is dark.
class JellyfinityApp extends StatelessWidget {
  const JellyfinityApp({
    super.key,
    required this.router,
    required this.session,
    required this.playback,
    required this.settings,
    required this.mediaScope,
    required this.downloads,
    required this.offline,
    required this.favoritesRevision,
  });

  final GoRouter router;
  final SessionCubit session;
  final PlaybackCubit playback;
  final SettingsCubit settings;
  final MediaScopeCubit mediaScope;
  final DownloadsCubit downloads;
  final OfflineCubit offline;

  /// The one instance both the widget tree and `PendingFavoritesSync`
  /// (v0.4.3) bump — resolved once at the composition root like every
  /// other cross-cutting cubit here, rather than created inline the way
  /// v0.3.4 originally did before anything outside the tree needed it.
  final FavoritesRevisionCubit favoritesRevision;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SessionCubit>.value(value: session),
        BlocProvider<PlaybackCubit>.value(value: playback),
        BlocProvider<SettingsCubit>.value(value: settings),
        BlocProvider<MediaScopeCubit>.value(value: mediaScope),
        BlocProvider<DownloadsCubit>.value(value: downloads),
        BlocProvider<OfflineCubit>.value(value: offline),
        // The signal every "favorites changed" listener watches (v0.3.4);
        // sits above the whole router, the same level the other
        // cross-cutting cubits do.
        BlocProvider<FavoritesRevisionCubit>.value(value: favoritesRevision),
      ],
      child: MaterialApp.router(
        title: 'Jellyfinity',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
        scrollBehavior: const DesktopScrollBehavior(),
        builder: (context, child) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
              if (router.canPop()) router.pop();
            },
          },
          child: BlocSelector<PlaybackCubit, PlaybackUiState, MediaImage?>(
            selector: (state) => state.currentEntry?.image,
            builder: (context, image) => ColoredBox(
              color: context.tokens.colors.background,
              child: ArtworkBackground(
                image: image,
                child: ArtworkBackdropScope(
                  hasArtwork: image != null,
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
