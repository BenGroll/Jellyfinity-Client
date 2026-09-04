import 'package:flutter/material.dart';

import '../../../../core/result/partial.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../library/paged_collection_cubit.dart';

/// Renders a [PagedCollectionState] as a scrolling list or grid, with all
/// of its states.
///
/// One widget rather than one per screen, because the states a large
/// paged collection can be in are the interesting part and every music
/// screen has to get all of them right:
///
/// - **loading** shows [skeleton] — the shape of the content, never a
///   spinner on an empty page (`PHILOSOPHY.md` §2);
/// - **failed** shows the failure with a retry, but only when there is
///   nothing to show instead;
/// - **empty** says the collection is empty, which is not an error;
/// - **cached** puts a notice above the content saying it is saved rather
///   than current;
/// - **partial** keeps the rows that could not be read, marked;
/// - **loading another window** is a footer under the content, never a
///   state that replaces it;
/// - **a failed window** is a retry under the content, for the same
///   reason.
class PagedCollectionView<T extends MediaItem> extends StatelessWidget {
  const PagedCollectionView({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.skeleton,
    required this.emptyTitle,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onRetry,
    this.onRetryLoadMore,
    this.emptyMessage,
    this.emptyIcon = Icons.library_music_outlined,
    this.gridDelegate,
    this.unavailableBuilder,
    this.headerSlivers = const [],
    this.padding,
  });

  final PagedCollectionState<T> state;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// What the screen looks like before its data arrives.
  final Widget skeleton;

  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;

  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final VoidCallback? onRetryLoadMore;

  /// Non-null turns the items into a grid.
  final SliverGridDelegate? gridDelegate;

  /// How to render an entry that could not be read. When null, the
  /// unreadable entries are summarised at the end instead of listed —
  /// right for a grid of covers, wrong for a numbered track list.
  final Widget Function(BuildContext context, UnavailableItem item)?
  unavailableBuilder;

  /// Slivers pinned above the collection: a detail header, a filter row.
  final List<Widget> headerSlivers;

  final EdgeInsetsGeometry? padding;

  /// How far from the end to start loading the next window. Big enough
  /// that a fast scroll stays ahead of the user, small enough that idle
  /// browsing does not pull windows nobody looks at.
  static const int prefetchThreshold = 12;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final insets =
        padding ??
        EdgeInsets.fromLTRB(t.spacing.md, 0, t.spacing.md, t.spacing.xxl);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        // Always scrollable, so pull-to-refresh works on a screen holding
        // an error or an empty state too.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...headerSlivers,
          if (state.isCached)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  t.spacing.md,
                  t.spacing.sm,
                  t.spacing.md,
                  t.spacing.sm,
                ),
                child: const SavedCopyNotice(),
              ),
            ),
          ..._content(context, insets),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, EdgeInsetsGeometry insets) {
    if (state.status == CollectionStatus.failed) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorStateView.forFailure(state.failure!, onRetry: onRetry),
        ),
      ];
    }

    if (!state.isReady) {
      return [
        SliverPadding(
          padding: insets,
          sliver: SliverToBoxAdapter(child: skeleton),
        ),
      ];
    }

    if (state.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyStateView(
            title: emptyTitle,
            message: emptyMessage,
            icon: emptyIcon,
          ),
        ),
      ];
    }

    final grid = gridDelegate;
    final delegate = SliverChildBuilderDelegate((context, index) {
      _maybeLoadMore(index);
      return itemBuilder(context, state.items[index], index);
    }, childCount: state.items.length);

    return [
      SliverPadding(
        padding: insets,
        sliver: grid == null
            ? SliverList(delegate: delegate)
            : SliverGrid(delegate: delegate, gridDelegate: grid),
      ),
      if (state.isPartial) ..._unavailable(context, insets),
      SliverToBoxAdapter(
        child: _Footer(
          isLoadingMore: state.isLoadingMore,
          failure: state.loadMoreFailure,
          onRetry: onRetryLoadMore,
        ),
      ),
    ];
  }

  List<Widget> _unavailable(BuildContext context, EdgeInsetsGeometry insets) {
    final builder = unavailableBuilder;
    if (builder == null) {
      return [
        SliverToBoxAdapter(
          child: _UnavailableSummary(count: state.unavailable.length),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: insets,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => builder(context, state.unavailable[index]),
            childCount: state.unavailable.length,
          ),
        ),
      ),
    ];
  }

  /// Asks for the next window a screenful before it is needed, from
  /// inside the builder — the list itself is the only thing that knows
  /// how far the user has actually got.
  void _maybeLoadMore(int index) {
    if (!state.hasMore || state.isLoadingMore) return;
    if (index < state.items.length - prefetchThreshold) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
  }
}

/// Says, above the content, that this is Jellyfinity's saved copy.
///
/// The alternative — showing saved data silently — is the thing
/// `PHILOSOPHY.md` §2 rules out: the user would have no way to tell an
/// out-of-date library from a current one.
class SavedCopyNotice extends StatelessWidget {
  const SavedCopyNotice({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.sm,
        vertical: t.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: t.colors.surfaceSunken,
        borderRadius: t.radii.smBorder,
        border: Border.all(color: t.colors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: t.colors.textSecondary,
          ),
          SizedBox(width: t.spacing.xs),
          Expanded(
            child: Text(
              message ??
                  'Showing your saved copy — Jellyfinity could not reach '
                      'the server.',
              style: t.typography.caption.copyWith(
                color: t.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The end of a paged list: quiet when there is nothing to say, a footer
/// while the next window loads, a local retry when one failed.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.isLoadingMore,
    required this.failure,
    required this.onRetry,
  });

  final bool isLoadingMore;
  final Object? failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (failure != null) {
      return Padding(
        padding: EdgeInsets.all(t.spacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Could not load more.',
                style: t.typography.bodyMedium.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
            ),
            SizedBox(width: t.spacing.sm),
            if (onRetry != null)
              AppButton(
                label: 'Try again',
                onPressed: onRetry,
                variant: AppButtonVariant.secondary,
              ),
          ],
        ),
      );
    }

    if (!isLoadingMore) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSkeleton(height: 14),
          SizedBox(height: t.spacing.xs),
          const AppSkeleton(height: 14),
        ],
      ),
    );
  }
}

/// For grids, where an unreadable cover has no sensible tile: how many
/// entries could not be read, without pretending they were not there.
class _UnavailableSummary extends StatelessWidget {
  const _UnavailableSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.sm,
      ),
      child: Row(
        children: [
          const UnavailableBadge(),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Text(
              count == 1
                  ? '1 item could not be read.'
                  : '$count items could not be read.',
              style: t.typography.caption.copyWith(
                color: t.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
