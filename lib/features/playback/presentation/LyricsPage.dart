import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/service_locator.dart';
import '../../../app/playback/PlaybackCubit.dart';
import '../../../app/playback/PlaybackUiState.dart';
import '../../../design/design.dart';
import '../../../domain/playback/Lyrics.dart';
import '../../../domain/playback/QueueEntry.dart';
import 'lyrics_cubit.dart';

/// The current track's lyrics (v0.1.5). A child route of Now Playing, so
/// leaving it returns to the player rather than to wherever the player was
/// opened from.
class LyricsPage extends StatelessWidget {
  const LyricsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackCubit, PlaybackUiState>(
      builder: (context, state) {
        final entry = state.currentEntry;
        return AppScaffold(
          title: 'Lyrics',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          body: entry == null
              ? const EmptyStateView(
                  title: 'Nothing playing',
                  message: 'Play a song from your library to see its lyrics.',
                  icon: Icons.music_note_outlined,
                )
              : _LyricsContent(entry: entry, position: state.position),
        );
      },
    );
  }
}

class _LyricsContent extends StatefulWidget {
  const _LyricsContent({required this.entry, required this.position});

  final QueueEntry entry;
  final Duration position;

  @override
  State<_LyricsContent> createState() => _LyricsContentState();
}

class _LyricsContentState extends State<_LyricsContent> {
  late final LyricsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<LyricsCubit>()..open(widget.entry.id);
  }

  @override
  void didUpdateWidget(covariant _LyricsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.id != oldWidget.entry.id) {
      _cubit.open(widget.entry.id);
    }
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LyricsCubit>.value(
      value: _cubit,
      child: BlocBuilder<LyricsCubit, LyricsState>(
        builder: (context, state) {
          if (state.isLoading) return const _LyricsSkeleton();

          final failure = state.failure;
          if (failure != null) {
            return ErrorStateView.forFailure(
              failure,
              title: 'Lyrics unavailable',
              onRetry: _cubit.retry,
            );
          }

          final lyrics = state.lyrics;
          if (lyrics == null) {
            return const EmptyStateView(
              title: 'No lyrics available',
              message: "Jellyfinity couldn't find lyrics for this track.",
              icon: Icons.lyrics_outlined,
            );
          }

          return lyrics.isSynchronized
              ? _SyncedLyricsView(lyrics: lyrics, position: widget.position)
              : _PlainLyricsView(lyrics: lyrics);
        },
      ),
    );
  }
}

/// A handful of centered text-shaped placeholders while lyrics load
/// (`PHILOSOPHY.md` §2: render the known structure, not a bare spinner).
class _LyricsSkeleton extends StatelessWidget {
  const _LyricsSkeleton();

  static const List<double> _widths = [0.5, 0.7, 0.4, 0.6, 0.3];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.xxl,
        vertical: t.spacing.xl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final width in _widths)
            Padding(
              padding: EdgeInsets.symmetric(vertical: t.spacing.sm),
              child: FractionallySizedBox(
                widthFactor: width,
                child: const AppSkeleton(height: 16),
              ),
            ),
        ],
      ),
    );
  }
}

/// The baseline lyrics presentation: every line, in order, no timing.
class _PlainLyricsView extends StatelessWidget {
  const _PlainLyricsView({required this.lyrics});

  final Lyrics lyrics;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.lg,
        vertical: t.spacing.xl,
      ),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.symmetric(vertical: t.spacing.xs),
        child: Text(
          lyrics.lines[index].text,
          textAlign: TextAlign.center,
          style: t.typography.bodyLarge.copyWith(color: t.colors.textPrimary),
        ),
      ),
    );
  }
}

/// Synchronized lyrics: the line at [position] is highlighted and kept in
/// view. Only reached when [Lyrics.isSynchronized] is true, i.e. every
/// line's [LyricLine.start] is present and non-decreasing.
class _SyncedLyricsView extends StatefulWidget {
  const _SyncedLyricsView({required this.lyrics, required this.position});

  final Lyrics lyrics;
  final Duration position;

  @override
  State<_SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<_SyncedLyricsView> {
  late List<GlobalKey> _lineKeys = _keysFor(widget.lyrics);

  /// The last index a scroll was requested for, so an unchanged active
  /// line doesn't queue a new animation on every position tick.
  int _lastScrolledIndex = -1;

  static List<GlobalKey> _keysFor(Lyrics lyrics) =>
      List.generate(lyrics.lines.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(covariant _SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lyrics, widget.lyrics)) {
      _lineKeys = _keysFor(widget.lyrics);
      _lastScrolledIndex = -1;
    }
  }

  /// The last line whose start is at or before [position] — safe to scan
  /// linearly since a track's lyric line count never approaches the
  /// library sizes `PHILOSOPHY.md` §11 cares about.
  int _activeIndex(Duration position) {
    final lines = widget.lyrics.lines;
    var index = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].start! <= position) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  void _scrollToActive(int index) {
    if (index < 0 || index >= _lineKeys.length) return;
    final lineContext = _lineKeys[index].currentContext;
    if (lineContext == null) return;
    Scrollable.ensureVisible(
      lineContext,
      alignment: 0.4,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final activeIndex = _activeIndex(widget.position);
    if (activeIndex != _lastScrolledIndex) {
      _lastScrolledIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToActive(activeIndex);
      });
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.lg,
        vertical: t.spacing.xl,
      ),
      itemCount: widget.lyrics.lines.length,
      itemBuilder: (context, index) {
        final isActive = index == activeIndex;
        return Padding(
          key: _lineKeys[index],
          padding: EdgeInsets.symmetric(vertical: t.spacing.xs),
          child: Text(
            widget.lyrics.lines[index].text,
            textAlign: TextAlign.center,
            style: (isActive ? t.typography.titleLarge : t.typography.bodyLarge)
                .copyWith(
                  color: isActive ? t.colors.accent : t.colors.textSecondary,
                ),
          ),
        );
      },
    );
  }
}
