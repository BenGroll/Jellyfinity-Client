import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/result/failure.dart';
import '../../../../core/result/partial.dart';
import '../../../../core/result/result.dart';
import '../../../../domain/connectivity/OfflineMode.dart';
import '../../../../domain/media/media.dart';
import '../offline_reload.dart';

/// Where a collection screen is in its life.
///
/// Deliberately coarse: the interesting distinctions — refreshing, loading
/// another window, showing saved data, holding an incomplete window — are
/// flags on [PagedCollectionState] rather than statuses, because they are
/// things that happen *while* content is on screen and a status would
/// force the screen to choose between them.
enum CollectionStatus {
  /// Nothing asked for yet.
  initial,

  /// The first window is on its way; the screen shows its skeleton.
  loading,

  /// There is content to render, whatever else is also true.
  ready,

  /// The first window failed and there is nothing saved to fall back on.
  failed,
}

/// Everything a paged media screen needs to render itself honestly.
///
/// `PHILOSOPHY.md` §2 asks the UI to distinguish loading, partially
/// loaded, loaded, empty, refreshing, offline, cached, unavailable and
/// failed. Each of those is answerable from this one object, which is why
/// it is a single state class rather than a hierarchy: a list can be
/// ready *and* refreshing *and* cached *and* missing two rows at once.
class PagedCollectionState<T extends MediaItem> extends Equatable {
  const PagedCollectionState({
    this.status = CollectionStatus.initial,
    this.items = const [],
    this.unavailable = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.source = PageSource.server,
    this.failure,
    this.loadMoreFailure,
  });

  final CollectionStatus status;

  /// Everything loaded so far, in the server's order.
  final List<T> items;

  /// Rows that arrived but could not be understood, kept so they can be
  /// shown as unavailable instead of vanishing.
  final List<UnavailableItem> unavailable;

  final bool hasMore;

  /// Another window is in flight; the list shows a footer, not a spinner
  /// over the content it already has.
  final bool isLoadingMore;

  /// A pull-to-refresh is running. The existing content stays on screen
  /// throughout — `PHILOSOPHY.md` §2: preserve what is loaded.
  final bool isRefreshing;

  /// Whether what is on screen came from the server or from the saved
  /// copy.
  final PageSource source;

  /// Why the first window failed. Only set with [CollectionStatus.failed].
  final Failure? failure;

  /// Why the *next* window failed, which must not take the screen down
  /// with it — the user keeps everything already loaded and a retry.
  final Failure? loadMoreFailure;

  bool get isReady => status == CollectionStatus.ready;

  /// Loaded, and there is genuinely nothing in this collection.
  bool get isEmpty => isReady && items.isEmpty && unavailable.isEmpty;

  /// Showing saved data because the server did not answer.
  bool get isCached => source.isCached;

  /// Something in this collection could not be read.
  bool get isPartial => unavailable.isNotEmpty;

  PagedCollectionState<T> copyWith({
    CollectionStatus? status,
    List<T>? items,
    List<UnavailableItem>? unavailable,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isRefreshing,
    PageSource? source,
    Failure? failure,
    Failure? loadMoreFailure,
    bool clearFailure = false,
    bool clearLoadMoreFailure = false,
  }) {
    return PagedCollectionState<T>(
      status: status ?? this.status,
      items: items ?? this.items,
      unavailable: unavailable ?? this.unavailable,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      source: source ?? this.source,
      failure: clearFailure ? null : (failure ?? this.failure),
      loadMoreFailure: clearLoadMoreFailure
          ? null
          : (loadMoreFailure ?? this.loadMoreFailure),
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    unavailable,
    hasMore,
    isLoadingMore,
    isRefreshing,
    source,
    failure,
    loadMoreFailure,
  ];
}

/// The paging behaviour every music collection screen shares.
///
/// One window is asked for at a time and appended; nothing here ever holds
/// a whole collection, and nothing here sorts or filters — the server did
/// both (`PHILOSOPHY.md` §11). Subclasses supply [fetch] and, if they take
/// parameters, call [reload] when those change.
///
/// The rules that make a large list feel solid live here rather than in
/// each screen:
///
/// - a failed *next* window never discards the windows already loaded;
/// - a refresh keeps the current content on screen until it is replaced;
/// - a window that arrives with unusable rows still advances the cursor,
///   so paging cannot stall on a row the server keeps sending;
/// - overlapping requests are ignored rather than interleaved.
abstract class PagedCollectionCubit<T extends MediaItem>
    extends Cubit<PagedCollectionState<T>>
    with OfflineReload<PagedCollectionState<T>> {
  PagedCollectionCubit({
    this.pageSize = PageRequest.defaultLimit,
    OfflineMode? offlineMode,
  }) : super(PagedCollectionState<T>()) {
    bindOfflineReload(offlineMode);
  }

  /// How many items to ask for at a time. Screens showing a handful of
  /// results (search sections) pass something much smaller.
  final int pageSize;

  /// Going on- or offline changes what every window would answer with, so
  /// re-read from the start — but only a list that has actually loaded,
  /// never a tab the user has not opened yet.
  @override
  void onOfflineChanged() {
    if (state.status != CollectionStatus.initial) reload();
  }

  PageRequest? _next;
  bool _busy = false;

  /// Drained right after a fetch clears [_busy]: if a reload was asked for
  /// mid-flight, run it now and tell the caller to stop emitting the
  /// window it just fetched (which was read under parameters that have
  /// since changed).
  bool _drainedQueuedReload() {
    if (!_reloadQueued) return false;
    _reloadQueued = false;
    unawaited(reload());
    return true;
  }

  /// A [reload] arrived while a fetch was in flight. Rather than blank the
  /// screen to a skeleton that a bailed `_loadFirst` would never fill, or
  /// let a stale in-flight window win, the current fetch finishes and then
  /// reloads once more with whatever parameters now hold — the offline
  /// switch and the "Downloads only" scope both change `fetch` mid-flight
  /// and both can fire on the same frame (v0.2.3).
  bool _reloadQueued = false;

  /// One window of this collection. The only thing a subclass must write.
  Future<Result<Page<T>>> fetch(PageRequest request);

  /// Loads the first window, unless it has already been asked for.
  ///
  /// Safe to call on every build: returning to a tab must not refetch the
  /// list the user was already looking at.
  Future<void> load() async {
    if (state.status != CollectionStatus.initial) return;
    await _loadFirst();
  }

  /// Discards what is loaded and starts again — for when the question
  /// itself changed (a new search term, a different artist).
  Future<void> reload() async {
    if (isClosed) return;
    if (_busy) {
      // Let the in-flight fetch land, then start over — see [_reloadQueued].
      _reloadQueued = true;
      return;
    }
    _next = null;
    emit(PagedCollectionState<T>());
    await _loadFirst();
  }

  /// Re-reads the first window while leaving the current content visible.
  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    emit(state.copyWith(isRefreshing: true, clearLoadMoreFailure: true));

    final result = await fetch(PageRequest(startIndex: 0, limit: pageSize));
    _busy = false;
    if (isClosed) return;
    if (_drainedQueuedReload()) return;

    switch (result) {
      case Ok<Page<T>>(:final value):
        emit(_ready(value));
      case Err<Page<T>>(:final failure):
        // The refresh failed but the list did not: keep what is on
        // screen and report the problem beside it.
        emit(state.copyWith(isRefreshing: false, loadMoreFailure: failure));
    }
  }

  /// Asks for the window after the one loaded last.
  Future<void> loadMore() async {
    final request = _next;
    if (_busy || request == null || !state.hasMore) return;
    if (state.loadMoreFailure != null) return;

    _busy = true;
    emit(state.copyWith(isLoadingMore: true));

    final result = await fetch(request);
    _busy = false;
    if (isClosed) return;
    if (_drainedQueuedReload()) return;

    switch (result) {
      case Ok<Page<T>>(:final value):
        _next = value.nextRequest(limit: pageSize);
        emit(
          state.copyWith(
            status: CollectionStatus.ready,
            items: [...state.items, ...value.items],
            unavailable: [...state.unavailable, ...value.unavailable],
            hasMore: value.hasMore,
            isLoadingMore: false,
            source: value.source,
          ),
        );
      case Err<Page<T>>(:final failure):
        emit(state.copyWith(isLoadingMore: false, loadMoreFailure: failure));
    }
  }

  /// Retries only the window that failed, keeping everything before it.
  Future<void> retryLoadMore() async {
    if (state.loadMoreFailure == null) return;
    emit(state.copyWith(clearLoadMoreFailure: true));
    await loadMore();
  }

  Future<void> _loadFirst() async {
    if (_busy) return;
    _busy = true;
    emit(state.copyWith(status: CollectionStatus.loading, clearFailure: true));

    final result = await fetch(PageRequest(startIndex: 0, limit: pageSize));
    _busy = false;
    if (isClosed) return;
    if (_drainedQueuedReload()) return;

    switch (result) {
      case Ok<Page<T>>(:final value):
        emit(_ready(value));
      case Err<Page<T>>(:final failure):
        emit(
          PagedCollectionState<T>(
            status: CollectionStatus.failed,
            failure: failure,
          ),
        );
    }
  }

  PagedCollectionState<T> _ready(Page<T> page) {
    _next = page.nextRequest(limit: pageSize);
    return PagedCollectionState<T>(
      status: CollectionStatus.ready,
      items: page.items,
      unavailable: page.unavailable,
      hasMore: page.hasMore,
      source: page.source,
    );
  }
}
