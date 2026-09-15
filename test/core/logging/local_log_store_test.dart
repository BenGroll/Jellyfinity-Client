import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/logging/LocalLogStore.dart';
import 'package:jellyfinity/core/logging/Logger.dart';

void main() {
  group('LocalLogStore', () {
    test('retains a detailed remote failure for copying', () {
      final store = LocalLogStore();
      final stack = StackTrace.current;

      store.add(
        level: LogLevel.error,
        message: 'Connected playback command timed out.',
        error: 'target did not acknowledge',
        stackTrace: stack,
      );

      expect(store.entries, hasLength(1));
      expect(store.entries.single.isRemote, isTrue);
      expect(store.text(remoteOnly: true), contains('target did not acknowledge'));
      expect(store.text(remoteOnly: true), contains('#0'));
    });

    test('keeps all context while the Remote view filters it', () {
      final store = LocalLogStore()
        ..add(level: LogLevel.info, message: 'Library refresh started.')
        ..add(level: LogLevel.info, message: 'Connected playback opened.');

      expect(store.entries, hasLength(2));
      expect(store.text(remoteOnly: true), contains('Connected playback opened.'));
      expect(store.text(remoteOnly: true), isNot(contains('Library refresh')));
      expect(store.text(), contains('Library refresh started.'));
    });
  });
}
