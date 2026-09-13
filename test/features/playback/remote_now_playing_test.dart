import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/PlaybackControlCubit.dart';
import 'package:jellyfinity/app/di/service_locator.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedDevice.dart';
import 'package:jellyfinity/domain/connected_playback/device_reachability.dart';
import 'package:jellyfinity/domain/connected_playback/remote_command_kind.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/domain/playback/PlaybackQueue.dart';
import 'package:jellyfinity/domain/playback/QueueEntry.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';
import 'package:jellyfinity/features/playback/presentation/MiniPlayer.dart';
import 'package:jellyfinity/features/playback/presentation/QueuePage.dart';

import '../../support/connected_playback/connected_playback_fixtures.dart';
import '../../support/playback_fakes.dart';
import '../../support/pump_app.dart';

/// v0.5.6's own definition of done, at the widget layer: the mini-player,
/// Now Playing and the queue render the "one presentation contract" the
/// roadmap asks for — bound to `PlaybackControlCubit` first, falling back
/// to local `PlaybackCubit` state only while nothing is being controlled.
///
/// `PlaybackControlCubit` itself is exercised end-to-end, over a real fake
/// network, by `playback_control_cubit_test.dart`; this file drives its
/// state directly (`Cubit.emit` is `@protected`, not private — the
/// ordinary way a bloc test seeds a state without re-running the whole
/// wire protocol) so the widgets under test are the only thing actually
/// being proven here.
void main() {
  Track track(String id, {String name = 'Track'}) => Track(
    id: MediaId(serverId: testScope.serverId, itemId: id),
    name: name,
    duration: const Duration(minutes: 3),
  );

  QueueEntry entry(String id, {String name = 'Track'}) =>
      QueueEntry.fromTrack(track(id, name: name));

  ConnectedDevice livingRoom({
    DeviceReachability reachability = DeviceReachability.ready,
  }) => device(
    sessionId: 'session-tv',
    name: 'Living Room',
    reachability: reachability,
  );

  PlaybackControlState playing({
    List<QueueEntry> entries = const [],
    int? currentIndex,
    Set<RemoteCommandKind> availableCommands = const {
      RemoteCommandKind.play,
      RemoteCommandKind.pause,
      RemoteCommandKind.playPause,
      RemoteCommandKind.previous,
      RemoteCommandKind.next,
      RemoteCommandKind.seek,
      RemoteCommandKind.setShuffle,
      RemoteCommandKind.setRepeat,
      RemoteCommandKind.jumpToQueueEntry,
    },
    PlaybackControlConnection connection = PlaybackControlConnection.synced,
  }) {
    var queue = PlaybackQueue.empty;
    if (entries.isNotEmpty && currentIndex != null) {
      queue = queue.withEntries(entries, startIndex: currentIndex);
    }
    return PlaybackControlState(
      device: livingRoom(),
      queue: queue,
      status: PlaybackStatus.playing,
      position: const Duration(seconds: 30),
      connection: connection,
      availableCommands: availableCommands,
    );
  }

  Future<PlaybackControlCubit> setUpControlling(
    WidgetTester tester, {
    PlaybackControlState? state,
  }) async {
    final scope = await pumpApp(tester, playback: fakePlaybackCubit());
    await scope.signIn();
    await tester.pumpAndSettle();

    final control = getIt<PlaybackControlCubit>();
    control.emit(
      state ?? playing(entries: [entry('a', name: 'So What')], currentIndex: 0),
    );
    await tester.pumpAndSettle();
    return control;
  }

  testWidgets('the mini-player shows the controlled device\'s real track '
      'instead of local playback', (tester) async {
    await setUpControlling(tester);

    expect(find.text('So What'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });

  testWidgets('Now Playing names the controlled device and disables a '
      'command the target does not advertise', (tester) async {
    await setUpControlling(
      tester,
      state: playing(
        entries: [entry('a', name: 'So What')],
        currentIndex: 0,
        availableCommands: const {
          RemoteCommandKind.play,
          RemoteCommandKind.pause,
          RemoteCommandKind.playPause,
          // shuffle deliberately left out, as if the target's own
          // advertisement never included it.
        },
      ),
    );

    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();

    expect(find.text('Controlling Living Room'), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_filled_rounded), findsOneWidget);
    final shuffleButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.shuffle_rounded),
    );
    expect(shuffleButton.onPressed, isNull);
  });

  testWidgets('the play/pause button is enabled exactly when the target '
      'advertises it, and pressing it does not crash without a live '
      'session behind it', (tester) async {
    await setUpControlling(tester);
    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();

    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.pause_circle_filled_rounded),
    );
    expect(button.onPressed, isNotNull);

    // Nothing actually backs a `ConnectedPlaybackControllerSession` for a
    // directly-emitted state (see the class doc), so this only proves the
    // wiring holds together end to end at the widget layer; the command's
    // own effect against a real target is `playback_control_cubit_test
    // .dart`'s job.
    await tester.tap(find.byIcon(Icons.pause_circle_filled_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('every connection state names itself rather than presenting '
      'stale state as live', (tester) async {
    final control = await setUpControlling(tester);
    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();

    for (final MapEntry(key: connection, value: message)
        in <PlaybackControlConnection, String>{
          PlaybackControlConnection.resynchronizing: 'Syncing',
          PlaybackControlConnection.reconnecting: 'Reconnecting',
          PlaybackControlConnection.targetEnded: 'no longer available',
        }.entries) {
      control.emit(
        playing(
          entries: [entry('a', name: 'So What')],
          currentIndex: 0,
          connection: connection,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(message),
        findsOneWidget,
        reason: '$connection',
      );
    }
  });

  testWidgets('the queue screen lists the remote queue in order, with no '
      'reorder handle or remove action', (tester) async {
    await setUpControlling(
      tester,
      state: playing(
        entries: [
          entry('a', name: 'So What'),
          entry('b', name: 'Blue in Green'),
          entry('c', name: 'Flamenco Sketches'),
        ],
        currentIndex: 0,
      ),
    );

    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    expect(find.byType(QueuePage), findsOneWidget);
    expect(find.text('Blue in Green'), findsOneWidget);
    expect(find.text('Flamenco Sketches'), findsOneWidget);
    // No drag handle and no remove action: incremental remote queue
    // editing is not part of any version's required deliverables (see
    // `SupportedRemoteCommands`).
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('tapping a queue row is wired to jump to it without '
      'crashing', (tester) async {
    await setUpControlling(
      tester,
      state: playing(
        entries: [
          entry('a', name: 'So What'),
          entry('b', name: 'Blue in Green'),
        ],
        currentIndex: 0,
      ),
    );
    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    // Same reasoning as the play/pause test above: nothing real backs
    // this directly-emitted state, so the row's own command effect is
    // `playback_control_cubit_test.dart`'s job — this only proves the tap
    // reaches `jumpToQueueEntry` without the widget layer crashing.
    await tester.tap(find.text('Blue in Green'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('remote queue rows are disabled when jumping is unsupported', (
    tester,
  ) async {
    await setUpControlling(
      tester,
      state: playing(
        entries: [
          entry('a', name: 'So What'),
          entry('b', name: 'Blue in Green'),
        ],
        currentIndex: 0,
        availableCommands: const {},
      ),
    );
    await tester.tap(find.text('So What'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    final row = find.ancestor(
      of: find.text('Blue in Green'),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(row).onTap, isNull);
  });

  testWidgets('stopping control returns every screen to local state '
      'without affecting the target', (tester) async {
    final localPlayback = fakePlaybackCubit();
    addTearDown(localPlayback.close);
    final scope = await pumpApp(tester, playback: localPlayback);
    await scope.signIn();
    await localPlayback.playNow([
      track('local', name: 'My Own Song'),
    ], startIndex: 0);
    await localPlayback.pause();
    await tester.pumpAndSettle();

    final control = getIt<PlaybackControlCubit>();
    control.emit(
      playing(entries: [entry('a', name: 'So What')], currentIndex: 0),
    );
    await tester.pumpAndSettle();

    // Scoped to the mini-player itself: "My Own Song" can legitimately
    // still appear elsewhere on Home (a "continue listening" card), which
    // is not what this test is about.
    final miniPlayerText = find.descendant(
      of: find.byType(MiniPlayer),
      matching: find.byType(Text),
    );
    expect(
      tester.widgetList<Text>(miniPlayerText).map((t) => t.data),
      contains('So What'),
    );

    unawaited(control.stop());
    await tester.pumpAndSettle();

    expect(
      tester.widgetList<Text>(miniPlayerText).map((t) => t.data),
      contains('My Own Song'),
    );
  });
}
