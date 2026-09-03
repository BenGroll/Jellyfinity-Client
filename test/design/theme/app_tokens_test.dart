import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/design/design.dart';

void main() {
  group('AppTheme', () {
    test('light and dark carry distinct AppTokens', () {
      final light = AppTheme.light().extension<AppTokens>()!;
      final dark = AppTheme.dark().extension<AppTokens>()!;

      expect(light.colors.background, isNot(dark.colors.background));
      expect(light.colors.textPrimary, isNot(dark.colors.textPrimary));
      // Non-colour tokens are shared across brightnesses.
      expect(light.spacing, dark.spacing);
      expect(light.radii, dark.radii);
    });

    test('the accent role is stable across light and dark', () {
      expect(
        AppTheme.light().extension<AppTokens>()!.colors.accent,
        AppTheme.dark().extension<AppTokens>()!.colors.accent,
      );
    });
  });

  group('AppTokens.lerp', () {
    test('t=0 and t=1 return the endpoints', () {
      final a = AppTheme.light().extension<AppTokens>()!;
      final b = AppTheme.dark().extension<AppTokens>()!;

      expect(a.lerp(b, 0).colors.background, a.colors.background);
      expect(a.lerp(b, 1).colors.background, b.colors.background);
    });

    test('a midpoint blends colours', () {
      final a = AppTheme.light().extension<AppTokens>()!;
      final b = AppTheme.dark().extension<AppTokens>()!;

      final mid = a.lerp(b, 0.5).colors.background;
      expect(mid, Color.lerp(a.colors.background, b.colors.background, 0.5));
      expect(mid, isNot(a.colors.background));
    });

    test('copyWith replaces only the given group', () {
      final base = AppTheme.dark().extension<AppTokens>()!;
      final swapped = base.copyWith(spacing: AppSpacing.standard);

      expect(swapped.colors, base.colors);
      expect(identical(swapped.spacing, AppSpacing.standard), isTrue);
    });
  });

  testWidgets('context.tokens resolves under AppTheme', (tester) async {
    late AppTokens seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            seen = context.tokens;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(seen.colors.background, Palette.dark.background);
    expect(seen.spacing.md, 16);
  });
}
