import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/PlaybackControlCubit.dart';
import 'package:jellyfinity/app/di/service_locator.dart';
import 'package:jellyfinity/domain/connected_playback/remote_command_kind.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/domain/playback/PlaybackQueue.dart';
import 'package:jellyfinity/domain/playback/QueueEntry.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';

import '../support/connected_playback/connected_playback_fixtures.dart';
import '../support/playback_fakes.dart';
import '../support/pump_app.dart';

/// The gap v0.5.7's scout found: `JellyfinityApp`'s hardware media-key
/// `CallbackShortcuts` always drove local `PlaybackCubit`, even while this
/// device was remote-controlling another one — a media key press would
/// silently act on a dormant local queue no screen was even showing,
/// instead of the device actually being controlled. This proves the fix
/// the same way `remote_now_playing_test.dart` proves the mini-player's
/// own "bound to `PlaybackControlCubit` first" contract: seed a
/// controlling state directly (`Cubit.emit` is `@protected`, not
/// private), then check local playback never moved.
void main() {
  Track track(String id, String name) => Track(
    id: MediaId(serverId: testScope.serverId, itemId: id),
    name: name,
    duration: const Duration(minutes: 3),
  );

  testWidgets(
    'media keys reach the controlled device instead of local playback '
    'while this device is remote-controlling one',
    (tester) async {
      final engine = FakePlaybackEngine();
      final playback = fakePlaybackCubit(engine: engine);
      final scope = await pumpApp(tester, playback: playback);
      await scope.signIn();
      await playback.playNow([track('local', 'Local song')], startIndex: 0);
      await tester.pumpAndSettle();
      engine.calls.clear();

      final control = getIt<PlaybackControlCubit>();
      control.emit(
        PlaybackControlState(
          device: device(sessionId: 'session-tv'),
          queue: PlaybackQueue.empty.withEntries([
            QueueEntry.fromTrack(track('remote', 'Remote song')),
          ], startIndex: 0),
          status: PlaybackStatus.playing,
          availableCommands: const {
            RemoteCommandKind.playPause,
            RemoteCommandKind.next,
            RemoteCommandKind.previous,
            RemoteCommandKind.seek,
          },
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaTrackNext);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaTrackPrevious);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaFastForward);
      await tester.pump();

      expect(engine.calls, isEmpty);
      expect(playback.state.currentEntry?.id.itemId, 'local');
      expect(playback.state.isPlaying, isTrue);

      // Local playback was never touched, so its position-save timer is
      // still armed — stop it before the test ends rather than leaving a
      // pending timer for the framework to complain about.
      await playback.pause();
    },
  );

  testWidgets(
    'media keys still drive local playback when nothing is being '
    'remote-controlled',
    (tester) async {
      final engine = FakePlaybackEngine();
      final playback = fakePlaybackCubit(engine: engine);
      final scope = await pumpApp(tester, playback: playback);
      await scope.signIn();
      await playback.playNow([track('local', 'Local song')], startIndex: 0);
      await tester.pumpAndSettle();
      engine.calls.clear();

      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
      await tester.pump();

      expect(engine.calls, contains('pause'));
    },
  );
}
