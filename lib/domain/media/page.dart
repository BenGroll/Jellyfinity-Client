import 'package:equatable/equatable.dart';

import '../../core/result/partial.dart';

/// Which slice of a collection a caller wants.
///
/// `PHILOSOPHY.md` §11: no repository ever offers "give me everything".
/// A 130k-track library is browsed one window at a time, and the window
/// is the caller's decision, not the repository's.
class PageRequest extends Equatable {
  const PageRequest({this.startIndex = 0, this.limit = defaultLimit})
    : assert(startIndex >= 0, 'startIndex cannot be negative'),
      assert(limit > 0, 'limit must be positive');

  /// The first window of a collection.
  const PageRequest.first({int limit = defaultLimit})
    : this(startIndex: 0, limit: limit);

  /// Big enough that scrolling stays ahead of the user, small enough that
  /// one page decodes quickly on a phone.
  static const int defaultLimit = 100;

  /// How many items to skip.
  final int startIndex;

  /// How many items to return at most.
  final int limit;

  /// The window after this one.
  PageRequest next() =>
      PageRequest(startIndex: startIndex + limit, limit: limit);

  @override
  List<Object?> get props => [startIndex, limit];

  @override
  String toString() => 'PageRequest($startIndex..${startIndex + limit})';
}

/// Where a window of media came from.
///
/// `PHILOSOPHY.md` §2 lists "cached" and "offline" among the states the UI
/// must be able to tell apart, so freshness is part of what a read
/// returns. This is deliberately *not* which implementation answered
/// (ADR-0010: the UI never learns that) — only whether what it is holding
/// is current.
enum PageSource {
  /// Read from the server during this request.
  server,

  /// Served from Jellyfinity's local copy because the server could not be
  /// reached. Still worth showing; must be shown as saved rather than
  /// current.
  cache;

  bool get isCached => this == cache;
}

/// One window of a larger collection, plus what it takes to ask for the
/// next one.
///
/// The items are held as a [Partial] (ADR-0004) rather than a plain list,
/// because a page is exactly where partial success shows up: a row the
/// server sent but Jellyfinity could not make sense of must neither be
/// dropped in silence nor fail the whole page. It lands in
/// [unavailable] with a reason and the other 99 items still render.
class Page<T> extends Equatable {
  const Page({
    required this.content,
    required this.startIndex,
    required this.totalCount,
    this.source = PageSource.server,
  });

  /// A page holding exactly these items, as the whole collection. Handy
  /// for tests and for local sources that already have everything.
  factory Page.of(List<T> items, {PageSource source = PageSource.server}) =>
      Page(
        content: Partial(available: items),
        startIndex: 0,
        totalCount: items.length,
        source: source,
      );

  /// An empty page — no items, nothing more to load.
  const Page.empty({this.source = PageSource.server})
    : content = const Partial(available: []),
      startIndex = 0,
      totalCount = 0;

  /// The window's items, with anything unusable recorded alongside.
  final Partial<T> content;

  /// The index of the first item in this window within the collection.
  final int startIndex;

  /// How many items the collection holds in total, as the source
  /// reported it.
  final int totalCount;

  /// Whether this window is current or saved. See [PageSource].
  final PageSource source;

  bool get isCached => source.isCached;

  List<T> get items => content.available;

  List<UnavailableItem> get unavailable => content.unavailable;

  bool get hasUnavailable => content.hasUnavailable;

  bool get isEmpty => items.isEmpty && unavailable.isEmpty;

  /// How many of the collection's items this window accounts for —
  /// including the ones that could not be produced, since the source
  /// still consumed them.
  int get consumed => items.length + unavailable.length;

  /// Whether asking for another window can return anything.
  bool get hasMore => startIndex + consumed < totalCount;

  /// The request that fetches the next window, or `null` at the end.
  PageRequest? nextRequest({int? limit}) {
    if (!hasMore) return null;
    return PageRequest(
      startIndex: startIndex + consumed,
      limit: limit ?? (consumed > 0 ? consumed : PageRequest.defaultLimit),
    );
  }

  @override
  List<Object?> get props => [content, startIndex, totalCount, source];
}
