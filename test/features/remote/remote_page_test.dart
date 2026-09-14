import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/ConnectedPlaybackScopeOf.dart';
import 'package:jellyfinity/domain/media/media.dart';

import '../../support/connected_playback/FakeDevicePresenceSource.dart';
import '../../support/connected_playback/connected_playback_fixtures.dart'
    show device;
import '../../support/playback_fakes.dart';
import '../../support/pump_app.dart';

Track _track(String itemId, {String name = 'Track'}) => Track(
  id: MediaId(serverId: 's1', itemId: itemId),
  name: name,
  duration: const Duration(minutes: 3),
);

Future<void> _openRemote(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Remote'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Remote is reachable from the shell and lists this device',
    (tester) async {
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final scope = await pumpApp(tester, playback: playback);
      await scope.signIn();
      await tester.pumpAndSettle();

      await _openRemote(tester);

      expect(find.text('This device'), findsOneWidget);
      expect(
        find.text('No other Jellyfinity devices found on this server yet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows a reachable peer and offers to bring paused local playback back',
    (tester) async {
      final presence = FakeDevicePresenceSource();
      final playback = fakePlaybackCubit();
      addTearDown(playback.close);
      final scope = await pumpApp(
        tester,
        playback: playback,
        devicePresence: presence,
      );
      await scope.signIn();
      await tester.pumpAndSettle();

      await playback.playNow([_track('a', name: 'So What')], startIndex: 0);
      await playback.pause();
      await tester.pumpAndSettle();

      final playbackScope = connectedPlaybackScopeOf(scope.cubit.state)!;
      presence.emitDevices(playbackScope, [
        device(
          scope: playbackScope,
          sessionId: 'session-tv',
          name: 'Living Room TV',
        ),
      ]);
      await tester.pumpAndSettle();

      await _openRemote(tester);

      expect(find.text('Living Room TV'), findsOneWidget);
      expect(find.text('Paused here — tap to bring it back'), findsOneWidget);
    },
  );
}
