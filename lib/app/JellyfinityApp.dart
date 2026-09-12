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
import 'platform/television_mode.dart';
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
class JellyfinityApp extends StatefulWidget {
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
    this.televisionMode,
    this.televisionDetector,
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

  /// Test/preview override. Production leaves this null and asks the Android
  /// host whether the current device is a television.
  final bool? televisionMode;
  final Future<bool> Function()? televisionDetector;

  @override
  State<JellyfinityApp> createState() => _JellyfinityAppState();
}

class _JellyfinityAppState extends State<JellyfinityApp> {
  late bool _isTelevision;

  @override
  void initState() {
    super.initState();
    _isTelevision = widget.televisionMode ?? false;
    if (widget.televisionMode == null) _detectTelevision();
  }

  @override
  void didUpdateWidget(covariant JellyfinityApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.televisionMode != oldWidget.televisionMode) {
      if (widget.televisionMode case final override?) {
        _isTelevision = override;
      } else {
        _detectTelevision();
      }
    }
  }

  Future<void> _detectTelevision() async {
    final detected =
        await (widget.televisionDetector ?? TelevisionModeDetector.detect)();
    if (mounted && widget.televisionMode == null && detected != _isTelevision) {
      setState(() => _isTelevision = detected);
    }
  }

  void _popRoute() {
    if (widget.router.canPop()) {
      widget.router.pop();
    } else if (_isTelevision) {
      SystemNavigator.pop();
    }
  }

  void _activateFocused() {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext != null) {
      Actions.maybeInvoke(focusedContext, const ActivateIntent());
    }
  }

  void _seekBy(Duration delta) {
    final state = widget.playback.state;
    if (state.currentEntry == null) return;
    final duration = state.duration;
    var target = state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (duration != null && target > duration) target = duration;
    widget.playback.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SessionCubit>.value(value: widget.session),
        BlocProvider<PlaybackCubit>.value(value: widget.playback),
        BlocProvider<SettingsCubit>.value(value: widget.settings),
        BlocProvider<MediaScopeCubit>.value(value: widget.mediaScope),
        BlocProvider<DownloadsCubit>.value(value: widget.downloads),
        BlocProvider<OfflineCubit>.value(value: widget.offline),
        // The signal every "favorites changed" listener watches (v0.3.4);
        // sits above the whole router, the same level the other
        // cross-cutting cubits do.
        BlocProvider<FavoritesRevisionCubit>.value(
          value: widget.favoritesRevision,
        ),
      ],
      child: MaterialApp.router(
        title: 'Jellyfinity',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(television: _isTelevision),
        darkTheme: AppTheme.dark(television: _isTelevision),
        themeMode: ThemeMode.dark,
        routerConfig: widget.router,
        scrollBehavior: const DesktopScrollBehavior(),
        builder: (context, child) => TelevisionModeScope(
          isTelevision: _isTelevision,
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
                    _popRoute,
                const SingleActivator(LogicalKeyboardKey.browserBack):
                    _popRoute,
                const SingleActivator(LogicalKeyboardKey.goBack): _popRoute,
                if (_isTelevision)
                  const SingleActivator(LogicalKeyboardKey.select):
                      _activateFocused,
                if (_isTelevision)
                  const SingleActivator(LogicalKeyboardKey.gameButtonA):
                      _activateFocused,
                const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
                    widget.playback.togglePlayPause,
                const SingleActivator(LogicalKeyboardKey.mediaPlay): () {
                  if (!widget.playback.state.isPlaying) {
                    widget.playback.resume();
                  }
                },
                const SingleActivator(LogicalKeyboardKey.mediaPause): () {
                  if (widget.playback.state.isPlaying) {
                    widget.playback.togglePlayPause();
                  }
                },
                const SingleActivator(LogicalKeyboardKey.mediaTrackNext):
                    widget.playback.next,
                const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious):
                    widget.playback.previous,
                const SingleActivator(
                  LogicalKeyboardKey.mediaFastForward,
                ): () =>
                    _seekBy(const Duration(seconds: 10)),
                const SingleActivator(LogicalKeyboardKey.mediaRewind): () =>
                    _seekBy(const Duration(seconds: -10)),
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
        ),
      ),
    );
  }
}
