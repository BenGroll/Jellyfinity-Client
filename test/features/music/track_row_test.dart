import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';
import 'package:jellyfinity/features/music/presentation/widgets/music_rows.dart';

import '../../support/music_fakes.dart';
import '../../support/pump_app.dart';

void main() {
  setUp(() {
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  testWidgets(
    'an unplayable track is greyed out and non-interactive (v0.2.3)',
    (tester) async {
      var tapped = false;
      await pumpThemed(
        tester,
        TrackRow(
          track: testTrack('t1', name: 'So What'),
          playable: false,
          onTap: () => tapped = true,
        ),
      );

      // Dimmed.
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1.0),
        findsOneWidget,
      );

      await tester.tap(find.text('So What'), warnIfMissed: false);
      await tester.pump();
      expect(tapped, isFalse);
    },
  );

  testWidgets('a playable track renders at full strength and taps through', (
    tester,
  ) async {
    var tapped = false;
    await pumpThemed(
      tester,
      TrackRow(
        track: testTrack('t1', name: 'So What'),
        onTap: () => tapped = true,
      ),
    );

    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1.0),
      findsNothing,
    );

    await tester.tap(find.text('So What'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
