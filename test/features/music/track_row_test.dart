import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media_availability.dart';
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

  testWidgets('a server-dropped download says "Only on this device" (v0.3.6)', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      TrackRow(
        track: testTrack(
          't1',
          name: 'So What',
          availability: MediaAvailability.localOnly,
        ),
      ),
    );

    expect(find.textContaining('Only on this device'), findsOneWidget);
  });

  group('bulk selection (v0.7.0)', () {
    testWidgets(
      'tapping a row in selection mode toggles it instead of playing',
      (tester) async {
        var tapped = false;
        var toggled = false;
        await pumpThemed(
          tester,
          TrackRow(
            track: testTrack('t1', name: 'So What'),
            onTap: () => tapped = true,
            selectionActive: true,
            onSelectToggle: () => toggled = true,
          ),
        );

        await tester.tap(find.text('So What'));
        await tester.pump();

        expect(toggled, isTrue);
        expect(tapped, isFalse);
      },
    );

    testWidgets('an unselected row shows the unchecked indicator', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        TrackRow(
          track: testTrack('t1', name: 'So What'),
          selectionActive: true,
          selected: false,
          onSelectToggle: () {},
        ),
      );

      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('a selected row shows the checked indicator', (tester) async {
      await pumpThemed(
        tester,
        TrackRow(
          track: testTrack('t1', name: 'So What'),
          selectionActive: true,
          selected: true,
          onSelectToggle: () {},
        ),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    });

    testWidgets(
      'a row that cannot be selected shows no indicator in selection mode',
      (tester) async {
        // Mirrors an unplayable row: callers pass `onSelectToggle: null`
        // the same way they already pass `onTap: null`.
        await pumpThemed(
          tester,
          TrackRow(
            track: testTrack('t1', name: 'So What'),
            selectionActive: true,
          ),
        );

        expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
        expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      },
    );

    testWidgets(
      'a long press on a selectable row starts selection rather than playing',
      (tester) async {
        var tapped = false;
        var toggled = false;
        await pumpThemed(
          tester,
          TrackRow(
            track: testTrack('t1', name: 'So What'),
            onTap: () => tapped = true,
            onSelectToggle: () => toggled = true,
          ),
        );

        await tester.longPress(find.text('So What'));
        await tester.pump();

        expect(toggled, isTrue);
        expect(tapped, isFalse);
      },
    );

    testWidgets('selection mode hides the overflow menu', (tester) async {
      await pumpThemed(
        tester,
        TrackRow(
          track: testTrack('t1', name: 'So What'),
          selectionActive: true,
          selected: false,
          onSelectToggle: () {},
          onPlayNext: () {},
          onAddToQueue: () {},
        ),
      );

      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    });
  });
}
