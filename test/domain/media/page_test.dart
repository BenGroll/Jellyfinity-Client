import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/domain/media/page.dart';

Page<String> _window({
  List<String> items = const [],
  List<UnavailableItem> unavailable = const [],
  int startIndex = 0,
  required int totalCount,
}) {
  return Page(
    content: Partial(available: items, unavailable: unavailable),
    startIndex: startIndex,
    totalCount: totalCount,
  );
}

void main() {
  group('PageRequest', () {
    test('walks a collection in windows', () {
      const first = PageRequest.first(limit: 50);

      expect(first.startIndex, 0);
      expect(first.next().startIndex, 50);
      expect(first.next().next().startIndex, 100);
      expect(first.next().limit, 50);
    });

    test('refuses a nonsensical window', () {
      expect(() => PageRequest(startIndex: -1), throwsAssertionError);
      expect(() => PageRequest(limit: 0), throwsAssertionError);
    });
  });

  group('Page', () {
    test('knows there is more of the collection to load', () {
      final page = _window(
        items: List.filled(100, 'track'),
        totalCount: 130000,
      );

      expect(page.hasMore, isTrue);
      expect(page.nextRequest()!.startIndex, 100);
      expect(page.nextRequest()!.limit, 100);
    });

    test('knows when it has reached the end', () {
      final page = _window(
        items: ['last'],
        startIndex: 129999,
        totalCount: 130000,
      );

      expect(page.hasMore, isFalse);
      expect(page.nextRequest(), isNull);
    });

    test('counts unusable rows as consumed so paging does not stall', () {
      // The server sent 10 rows; 2 could not be understood. The next
      // window still has to start after all 10, or the same broken rows
      // come back forever.
      final page = _window(
        items: List.filled(8, 'ok'),
        unavailable: const [
          UnavailableItem(id: 'a', reason: 'unreadable'),
          UnavailableItem(id: 'b', reason: 'unreadable'),
        ],
        totalCount: 30,
      );

      expect(page.consumed, 10);
      expect(page.nextRequest()!.startIndex, 10);
      expect(page.hasUnavailable, isTrue);
    });

    test('an empty page is empty and final', () {
      final page = Page<String>.empty();

      expect(page.isEmpty, isTrue);
      expect(page.hasMore, isFalse);
      expect(page.nextRequest(), isNull);
    });

    test('a page of everything reports itself complete', () {
      final page = Page.of(['a', 'b']);

      expect(page.items, ['a', 'b']);
      expect(page.totalCount, 2);
      expect(page.hasMore, isFalse);
    });
  });

  group('PageSource', () {
    test('a page is current unless it says otherwise', () {
      expect(Page.of(const ['a']).source, PageSource.server);
      expect(Page.of(const ['a']).isCached, isFalse);
      expect(const Page<String>.empty().isCached, isFalse);
    });

    test('a page served from the local copy says so', () {
      final page = Page.of(const ['a'], source: PageSource.cache);

      expect(page.isCached, isTrue);
      // Same items, different freshness: the UI has to be able to tell
      // these apart, so they must not compare equal.
      expect(page, isNot(Page.of(const ['a'])));
    });
  });
}
