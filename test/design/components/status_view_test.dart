import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/design/design.dart';

import '../../support/pump_app.dart';

void main() {
  group('EmptyStateView', () {
    testWidgets('renders title and message, no action by default', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const EmptyStateView(title: 'No albums', message: 'Nothing here yet'),
      );

      expect(find.text('No albums'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('shows an action when both label and callback are given', (
      tester,
    ) async {
      var tapped = 0;
      await pumpThemed(
        tester,
        EmptyStateView(
          title: 'No albums',
          actionLabel: 'Refresh',
          onAction: () => tapped++,
        ),
      );

      await tester.tap(find.text('Refresh'));
      expect(tapped, 1);
    });
  });

  group('ErrorStateView.forFailure', () {
    testWidgets('a RecoverableFailure gets a working retry action', (
      tester,
    ) async {
      var retried = 0;
      await pumpThemed(
        tester,
        ErrorStateView.forFailure(
          const RecoverableFailure('Request timed out'),
          onRetry: () => retried++,
        ),
      );

      expect(find.text('Request timed out'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('an UnavailableFailure shows no retry even with a callback', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        ErrorStateView.forFailure(
          const UnavailableFailure('Server unreachable'),
          onRetry: () {},
        ),
      );

      expect(find.text('Server unreachable'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('UnavailableContent', () {
    testWidgets('blocks pointer events when unavailable', (tester) async {
      var taps = 0;
      await pumpThemed(
        tester,
        UnavailableContent(
          isUnavailable: true,
          child: GestureDetector(
            onTap: () => taps++,
            child: const Text('track'),
          ),
        ),
      );

      await tester.tap(find.text('track'), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('passes the child through untouched when available', (
      tester,
    ) async {
      var taps = 0;
      await pumpThemed(
        tester,
        UnavailableContent(
          isUnavailable: false,
          child: GestureDetector(
            onTap: () => taps++,
            child: const Text('track'),
          ),
        ),
      );

      await tester.tap(find.text('track'));
      expect(taps, 1);
    });
  });
}
