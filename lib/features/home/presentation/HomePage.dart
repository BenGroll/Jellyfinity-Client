import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/connectivity/OfflineCubit.dart';
import '../../../app/di/service_locator.dart';
import '../../../app/playback/PlaybackCubit.dart';
import '../../../app/playback/PlaybackUiState.dart';
import '../../../app/router/route_paths.dart';
import '../../../app/settings/SettingsCubit.dart';
import '../../../app/downloads/DownloadsCubit.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../design/design.dart';
import '../../../domain/connectivity/OfflineLibraryScope.dart';
import '../../../domain/downloads/downloads.dart';
import '../../../domain/media/media.dart';
import '../../../domain/playback/QueueEntry.dart';
import '../../music/presentation/widgets/MediaArtwork.dart';
import 'RecentlyPlayedCubit.dart';

/// The Home section (v0.3.2).
///
/// No longer a placeholder: Home opens on what the user was doing —
/// **Continue listening** (the persisted queue from v0.0.9, restored
/// paused at launch) and **Recently played** (v0.3.1's listening history,
/// ADR-0025). Each section loads, empties and fails on its own; a dead
/// section is simply absent and never takes the screen down
/// (`PHILOSOPHY.md` §2). A modular, user-reorderable Home (`OUTLOOK.md`
/// §9) is still not this arc — strong defaults first.
///
/// Home has no "Browse music" button once there is something better to
/// show; the Library stays one tap away on the bottom navigation bar (and
/// the empty-Home state keeps the explicit affordance).
class HomePage extends StatelessWidget {
  const HomePage({super.key, this.recentlyPlayed});

  /// Injectable seam for widget tests; the graph supplies it in the app,
  /// the same pattern as [LibraryPage].
  final RecentlyPlayedCubit? recentlyPlayed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecentlyPlayedCubit>(
      create: (_) => (recentlyPlayed ?? getIt<RecentlyPlayedCubit>())..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<OfflineCubit>().state.isOffline;
    final limitedScope =
        context.watch<SettingsCubit>().state.offlineLibraryScope ==
        OfflineLibraryScope.limited;
    // Offline with the "Downloads only" scope, a section shows only what
    // can actually play; otherwise everything shows and the unplayable is
    // marked in place (ADR-0023).
    final downloadsOnly = offline && limitedScope;
    final catalog = context.watch<DownloadsCubit>().state;

    // A track starting while Home sits in the background is exactly when
    // "Recently played" goes stale — re-read it then, so it is current by
    // the time the user comes back to this tab.
    return BlocListener<PlaybackCubit, PlaybackUiState>(
      listenWhen: (previous, current) =>
          previous.currentEntry?.id != current.currentEntry?.id,
      listener: (context, _) => context.read<RecentlyPlayedCubit>().refresh(),
      child: BlocBuilder<PlaybackCubit, PlaybackUiState>(
        builder: (context, playback) {
          return BlocBuilder<RecentlyPlayedCubit, RecentlyPlayedState>(
            builder: (context, recent) {
              return _HomeBody(
                playback: playback,
                recent: recent,
                catalog: catalog,
                offline: offline,
                downloadsOnly: downloadsOnly,
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.playback,
    required this.recent,
    required this.catalog,
    required this.offline,
    required this.downloadsOnly,
  });

  final PlaybackUiState playback;
  final RecentlyPlayedState recent;
  final DownloadCatalog catalog;
  final bool offline;
  final bool downloadsOnly;

  bool _playable(ListeningContext ctx) {
    if (!offline) return true;
    return switch (ctx.kind) {
      ListeningContextKind.album =>
        catalog.statusFor(DownloadOwner.album(ctx.id)).completed > 0,
      ListeningContextKind.artist =>
        catalog.statusFor(DownloadOwner.artist(ctx.id)).completed > 0,
      ListeningContextKind.track => catalog.isDownloaded(ctx.id),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final current = playback.currentEntry;
    // Something to pick up: a restored (or paused) queue that is not
    // already playing. Under the downloads-only scope it also has to be
    // playable, or resuming it would only reach unavailable tracks.
    final resumeEntry = current != null && !playback.isPlaying ? current : null;
    final resumePlayable =
        resumeEntry != null &&
        (!offline || catalog.isDownloaded(resumeEntry.id));
    final showResume =
        resumeEntry != null && (!downloadsOnly || resumePlayable);

    final visibleRecent = downloadsOnly
        ? [
            for (final entry in recent.entries)
              if (_playable(entry.context)) entry,
          ]
        : recent.entries;

    final children = <Widget>[];

    if (showResume) {
      children.add(
        _ContinueListeningCard(
          entry: resumeEntry,
          position: playback.position,
          playable: resumePlayable,
          onResume: resumePlayable
              ? () {
                  context.read<PlaybackCubit>().resume();
                  context.pushNamed(RouteNames.nowPlaying);
                }
              : null,
          onOpenAlbum: resumeEntry.albumId == null
              ? null
              : () => context.pushNamed(
                  RouteNames.libraryAlbum,
                  pathParameters: {'id': resumeEntry.albumId!.key},
                ),
        ),
      );
    }

    switch (recent.status) {
      case RecentlyPlayedStatus.initial:
      case RecentlyPlayedStatus.loading:
        children
          ..add(const _SectionHeader('Recently played'))
          ..add(const _RecentlyPlayedSkeleton());
      case RecentlyPlayedStatus.failed:
        children
          ..add(const _SectionHeader('Recently played'))
          ..add(
            _SectionError(
              failure: recent.failure,
              onRetry: () => context.read<RecentlyPlayedCubit>().retry(),
            ),
          );
      case RecentlyPlayedStatus.loaded:
        if (visibleRecent.isNotEmpty) {
          children
            ..add(const _SectionHeader('Recently played'))
            ..add(
              _RecentlyPlayedStrip(
                entries: visibleRecent,
                isPlayable: _playable,
                onOpen: (ctx) => _open(context, ctx),
              ),
            );
        }
    }

    if (children.isEmpty) {
      return _EmptyHome(offline: offline);
    }

    return ListView(
      padding: EdgeInsets.symmetric(vertical: t.spacing.md),
      children: [
        for (final child in children)
          Padding(
            padding: EdgeInsets.only(bottom: t.spacing.md),
            child: child,
          ),
      ],
    );
  }

  void _open(BuildContext context, ListeningContext ctx) {
    switch (ctx.kind) {
      // Pushed onto the Home stack rather than switching to the Library
      // tab: a tap on Home should not move the user off Home. The detail
      // pages are the same ones the Library branch shows, and they own
      // their offline state (`AlbumDetailPage` / `ArtistDetailPage`).
      case ListeningContextKind.album:
        context.pushNamed(
          RouteNames.libraryAlbum,
          pathParameters: {'id': ctx.id.key},
        );
      case ListeningContextKind.artist:
        context.pushNamed(
          RouteNames.libraryArtist,
          pathParameters: {'id': ctx.id.key},
        );
      case ListeningContextKind.track:
        _playTrack(context, ctx.id);
    }
  }

  Future<void> _playTrack(BuildContext context, MediaId id) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final playbackCubit = context.read<PlaybackCubit>();
    final result = await context.read<RecentlyPlayedCubit>().resolveTrack(id);
    switch (result) {
      case Ok<Track>(:final value):
        await playbackCubit.playNow([value], startIndex: 0);
      case Err<Track>():
        messenger?.showSnackBar(
          const SnackBar(content: Text("Can't play that right now.")),
        );
    }
  }
}

/// A section title, the shared heading for every strip on Home.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(t.spacing.md, 0, t.spacing.md, t.spacing.xs),
      child: Text(
        title,
        style: t.typography.titleMedium.copyWith(color: t.colors.textPrimary),
      ),
    );
  }
}

/// "Continue listening": the one wide card at the top of Home.
class _ContinueListeningCard extends StatelessWidget {
  const _ContinueListeningCard({
    required this.entry,
    required this.position,
    required this.playable,
    required this.onResume,
    required this.onOpenAlbum,
  });

  final QueueEntry entry;
  final Duration position;
  final bool playable;
  final VoidCallback? onResume;
  final VoidCallback? onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final duration = entry.duration;
    final progress = (duration != null && duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: t.spacing.xs),
            child: Text(
              'Continue listening',
              style: t.typography.titleMedium.copyWith(
                color: t.colors.textPrimary,
              ),
            ),
          ),
          Material(
            color: t.colors.surface,
            borderRadius: t.radii.mdBorder,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onResume ?? onOpenAlbum,
              child: Padding(
                padding: EdgeInsets.all(t.spacing.sm),
                child: Row(
                  children: [
                    MediaArtwork(
                      image: entry.image,
                      kind: MediaKind.track,
                      size: 56,
                    ),
                    SizedBox(width: t.spacing.sm),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.typography.bodyLarge.copyWith(
                              color: t.colors.textPrimary,
                            ),
                          ),
                          if (entry.artist != null)
                            Text(
                              entry.artist!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.typography.caption.copyWith(
                                color: t.colors.textSecondary,
                              ),
                            ),
                          if (!playable)
                            Padding(
                              padding: EdgeInsets.only(top: t.spacing.xxs),
                              child: Text(
                                'Not available offline',
                                style: t.typography.caption.copyWith(
                                  color: t.colors.textSecondary,
                                ),
                              ),
                            )
                          else if (progress != null)
                            Padding(
                              padding: EdgeInsets.only(top: t.spacing.xs),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 3,
                                  backgroundColor: t.colors.surfaceSunken,
                                  color: t.colors.accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: t.spacing.xs),
                    Icon(
                      playable
                          ? Icons.play_circle_fill_rounded
                          : Icons.cloud_off_rounded,
                      color: playable
                          ? t.colors.accent
                          : t.colors.textSecondary,
                      size: 36,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The horizontal strip of "Recently played" cards.
class _RecentlyPlayedStrip extends StatelessWidget {
  const _RecentlyPlayedStrip({
    required this.entries,
    required this.isPlayable,
    required this.onOpen,
  });

  final List<ListeningHistoryEntry> entries;
  final bool Function(ListeningContext ctx) isPlayable;
  final void Function(ListeningContext ctx) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: _cardWidth + 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
        itemCount: entries.length,
        separatorBuilder: (_, _) => SizedBox(width: t.spacing.sm),
        itemBuilder: (context, index) {
          final ctx = entries[index].context;
          final playable = isPlayable(ctx);
          return _RecentlyPlayedCard(
            context: ctx,
            playable: playable,
            onTap: playable ? () => onOpen(ctx) : null,
          );
        },
      ),
    );
  }
}

const double _cardWidth = 132;

class _RecentlyPlayedCard extends StatelessWidget {
  const _RecentlyPlayedCard({
    required this.context,
    required this.playable,
    required this.onTap,
  });

  final ListeningContext context;
  final bool playable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext buildContext) {
    final t = buildContext.tokens;
    final circle = context.kind == ListeningContextKind.artist;
    final kindLabel = switch (context.kind) {
      ListeningContextKind.album => context.subtitle ?? 'Album',
      ListeningContextKind.artist => 'Artist',
      ListeningContextKind.track => context.subtitle ?? 'Song',
    };

    return Opacity(
      opacity: playable ? 1 : 0.45,
      child: SizedBox(
        width: _cardWidth,
        child: InkWell(
          onTap: onTap,
          borderRadius: t.radii.smBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MediaArtwork(
                image: context.image,
                kind: context.kind == ListeningContextKind.artist
                    ? MediaKind.artist
                    : context.kind == ListeningContextKind.album
                    ? MediaKind.album
                    : MediaKind.track,
                size: _cardWidth,
                shape: circle ? ArtworkShape.circle : ArtworkShape.rounded,
              ),
              SizedBox(height: t.spacing.xs),
              Text(
                context.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.bodyMedium.copyWith(
                  color: t.colors.textPrimary,
                ),
              ),
              Text(
                playable ? kindLabel : 'Not playable offline',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.caption.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A skeleton the same shape as the "Recently played" strip.
class _RecentlyPlayedSkeleton extends StatelessWidget {
  const _RecentlyPlayedSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: _cardWidth + 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
        itemCount: 4,
        separatorBuilder: (_, _) => SizedBox(width: t.spacing.sm),
        itemBuilder: (context, _) => SizedBox(
          width: _cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(
                width: _cardWidth,
                height: _cardWidth,
                borderRadius: t.radii.smBorder,
              ),
              SizedBox(height: t.spacing.xs),
              const AppSkeleton(height: 12, width: 100),
              SizedBox(height: t.spacing.xxs),
              const AppSkeleton(height: 10, width: 60),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact failure inside one section — it never takes Home down, so it
/// is a line and a retry, not a full-screen [ErrorStateView].
class _SectionError extends StatelessWidget {
  const _SectionError({required this.failure, required this.onRetry});

  final Failure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              failure?.message ?? "Couldn't load what you played lately.",
              style: t.typography.bodyMedium.copyWith(
                color: t.colors.textSecondary,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

/// The whole of Home before there is anything to resume or replay — a
/// fresh install, or a profile that has only ever browsed. Keeps the
/// explicit route to the library that the sections otherwise replace.
class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.library_music_outlined,
      title: 'Nothing to pick up yet',
      message: offline
          ? 'Play something and it will wait for you here.'
          : 'Play an album or a track and Home will open on it next time.',
      actionLabel: 'Browse music',
      onAction: () => context.goNamed(RouteNames.library),
    );
  }
}
