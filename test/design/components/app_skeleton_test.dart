import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/design/design.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('AppSkeletonList builds the requested number of rows', (
    tester,
  ) async {
    await pumpThemed(tester, const AppSkeletonList(itemCount: 4));

    expect(find.byType(AppSkeleton), findsNWidgets(4 * 3));
  });

  testWidgets('a shimmering skeleton keeps animating without settling', (
    tester,
  ) async {
    await pumpThemed(tester, const AppSkeleton(width: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // The shimmer loops forever, so pumpAndSettle would time out — the
    // skeleton is still there and the frame scheduler is still busy.
    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('reduce-motion renders a static block (settles immediately)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: AppSkeleton(width: 100)),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(AppSkeleton), findsOneWidget);
  });
}
