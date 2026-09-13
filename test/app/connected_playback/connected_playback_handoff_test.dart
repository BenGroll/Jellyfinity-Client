import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/ConnectedPlaybackTargetLink.dart';
import 'package:jellyfinity/app/connected_playback/SupportedRemoteCommands.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/domain/connected_playback/PlaybackTransfer.dart';
import 'package:jellyfinity/domain/connected_playback/transfer_refusal.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/media/Track.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';

import '../../support/TestLogger.dart';
import '../../support/connected_playback/FakeConnectedPlaybackNetwork.dart';
import '../../support/connected_playback/FakeConnectedPlaybackTransport.dart';
import '../../support/connected_playback/connected_playback_fixtures.dart';
import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/session_fakes.dart';
import '../../support/settings_fakes.dart';

/// v0.5.4's own definition of done: two real `ConnectedPlaybackTargetLink`s
/// — each with its own `PlaybackCubit`, engine and library — talking over
/// the same deliberately unreliable fake network v0.5.1-v0.5.3 already
/// proved the rest of the arc against. One transfers a real, playing
/// queue to the other and only one of them ends up producing sound.
const Duration _shortTimeout = Duration(milliseconds: 50);

void main() {
  Track track(String id, {String name = ''}) => Track(
    id: MediaId(serverId: testScope.serverId, itemId: id),
    name: name.isEmpty ? 'Track $id' : name,
    duration: const Duration(minutes: 3),
  );

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  late FakeConnectedPlaybackNetwork network;

  late FakePlaybackEngine sourceEngine;
  late PlaybackCubit sourcePlayback;
  late FakeConnectedPlaybackTransport sourceTransport;
  late ConnectedPlaybackTargetLink sourceLink;

  late FakePlaybackEngine targetEngine;
  late PlaybackCubit targetPlayback;
  late FakeConnectedPlaybackTransport targetTransport;
  late FakeMusicLibraryRepository targetLibrary;
  late ConnectedPlaybackTargetLink targetLink;

  PlaybackCubit buildPlayback(FakePlaybackEngine engine) => PlaybackCubit(
    engine,
    FakeQueueRepository(),
    FakeAudioSourceResolver(),
    RecordingPlaybackProgressRepository(),
    RecordingListeningHistoryRepository(),
    fakeSettingsCubit(),
  );

  setUp(() async {
    network = FakeConnectedPlaybackNetwork();

    sourceEngine = FakePlaybackEngine();
    sourcePlayback = buildPlayback(sourceEngine);
    sourceTransport = FakeConnectedPlaybackTransport(
      network: network,
      sessionId: 'session-phone',
      scope: testScope,
      acknowledgementTimeout: _shortTimeout,
    );
    sourceLink = ConnectedPlaybackTargetLink(
      sourcePlayback,
      sourceTransport,
      fakeSessionCubit(signedIn: fakeAuthSession()),
      FakeMusicLibraryRepository(),
      TestLogger(),
    )..handoffStepTimeout = _shortTimeout;
    await sourceLink.start();

    targetEngine = FakePlaybackEngine();
    targetPlayback = buildPlayback(targetEngine);
    targetTransport = FakeConnectedPlaybackTransport(
      network: network,
      sessionId: 'session-tv',
      scope: testScope,
      acknowledgementTimeout: _shortTimeout,
    );
    targetLibrary = FakeMusicLibraryRepository()
      ..trackList = [track('a'), track('b'), track('c')];
    targetLink = ConnectedPlaybackTargetLink(
      targetPlayback,
      targetTransport,
      fakeSessionCubit(signedIn: fakeAuthSession()),
      targetLibrary,
      TestLogger(),
    )..handoffStepTimeout = _shortTimeout;
    await targetLink.start();

    await sourcePlayback.playNow([
      track('a'),
      track('b'),
      track('c'),
    ], startIndex: 1);
    await sourcePlayback.seek(const Duration(seconds: 45));
    await settle();
  });

  tearDown(() async {
    await sourceLink.stop();
    await targetLink.stop();
    await sourcePlayback.close();
    await targetPlayback.close();
  });

  test('the full playable listening context arrives at the target, and only '
      'the target ends up owning playback', () async {
    final result = await sourceLink.transferTo(
      target: device(
        sessionId: 'session-tv',
        capabilities: supportedRemoteCommands,
      ),
      snapshot: sourceLink.snapshot!,
    );
    await settle();

    expect(result.isOk, isTrue);

    // The source gave up its audio, but its queue was never torn down.
    expect(sourceEngine.playing, isFalse);
    expect(sourceEngine.calls, contains('pause'));

    // The target resolved every entry through its own library and is
    // now the one producing sound, at the same track and position.
    expect(targetPlayback.state.queue.entries, hasLength(3));
    expect(targetPlayback.state.queue.currentIndex, 1);
    expect(targetPlayback.state.queue.entries[1].id.itemId, 'b');
    expect(targetEngine.playing, isTrue);
    expect(targetPlayback.state.position, const Duration(seconds: 45));
  });

  test('a paused source hands over paused, not resumed', () async {
    await sourcePlayback.pause();
    await settle();

    final result = await sourceLink.transferTo(
      target: device(
        sessionId: 'session-tv',
        capabilities: supportedRemoteCommands,
      ),
      snapshot: sourceLink.snapshot!,
    );
    await settle();

    expect(result.isOk, isTrue);
    expect(targetEngine.playing, isFalse);
    expect(targetPlayback.state.queue.entries, hasLength(3));
  });

  test(
    'true queue order and repeat mode survive the handoff under shuffle',
    () async {
      await sourcePlayback.toggleShuffle();
      await sourcePlayback.setRepeatMode(RepeatMode.all);
      await settle();
      final sourceOrder = sourcePlayback.state.queue.playOrder
          .map((i) => sourcePlayback.state.queue.entries[i].id.itemId)
          .toList();

      final result = await sourceLink.transferTo(
        target: device(
          sessionId: 'session-tv',
          capabilities: supportedRemoteCommands,
        ),
        snapshot: sourceLink.snapshot!,
      );
      await settle();

      expect(result.isOk, isTrue);
      expect(targetPlayback.state.queue.shuffleEnabled, isTrue);
      expect(targetPlayback.state.queue.repeatMode, RepeatMode.all);
      final targetOrder = targetPlayback.state.queue.playOrder
          .map((i) => targetPlayback.state.queue.entries[i].id.itemId)
          .toList();
      // The target does not reshuffle — it plays exactly the order it
      // was offered.
      expect(targetOrder, sourceOrder);
    },
  );

  test(
    'an entry the target cannot resolve refuses before the source stops',
    () async {
      targetLibrary.trackList = [track('a'), track('c')]; // 'b' missing

      final result = await sourceLink.transferTo(
        target: device(
          sessionId: 'session-tv',
          capabilities: supportedRemoteCommands,
        ),
        snapshot: sourceLink.snapshot!,
      );
      await settle();

      expect(result.isErr, isTrue);
      // Nothing stopped: the source is still the one playing.
      expect(sourceEngine.calls, isNot(contains('pause')));
      expect(sourcePlayback.state.isPlaying, isTrue);
      expect(targetPlayback.state.queue.isEmpty, isTrue);
    },
  );

  test(
    'a target already receiving a transfer refuses a second offer as busy',
    () async {
      targetLibrary.trackList = [
        ...targetLibrary.trackList,
        track('t0'),
        track('t1'),
      ];

      final first = TransferOffer(
        transferId: 'transfer-1',
        scope: testScope,
        sourceSessionId: 'session-phone',
        targetSessionId: 'session-tv',
        entries: entries(2),
        startIndex: 0,
      );
      final second = TransferOffer(
        transferId: 'transfer-2',
        scope: testScope,
        sourceSessionId: 'session-desktop',
        targetSessionId: 'session-tv',
        entries: entries(2),
        startIndex: 0,
      );

      final firstReadiness = await targetLink.prepare(first);
      final secondReadiness = await targetLink.prepare(second);

      expect(firstReadiness.isReady, isTrue);
      expect(secondReadiness.isReady, isFalse);
      expect(secondReadiness.refusal, TransferRefusal.busy);

      // A retry of the same transfer is answered the same way, not
      // refused as a second one.
      final retry = await targetLink.prepare(first);
      expect(retry.isReady, isTrue);
    },
  );

  test('a target that never answers the offer leaves the source playing, '
      'refusing with a timeout', () async {
    // Disconnected before the offer is even sent — the fake network's
    // stand-in for an unreachable device.
    network.disconnect('session-tv');

    final result = await sourceLink.transferTo(
      target: device(
        sessionId: 'session-tv',
        capabilities: supportedRemoteCommands,
      ),
      snapshot: sourceLink.snapshot!,
    );

    expect(result.isErr, isTrue);
    expect(sourceEngine.calls, isNot(contains('pause')));
    expect(sourcePlayback.state.isPlaying, isTrue);
  });

  test('a lost result after commit resumes the source, and a late one stops '
      'it again', () async {
    network.manualDelivery = true;

    final resultFuture = sourceLink.transferTo(
      target: device(
        sessionId: 'session-tv',
        capabilities: supportedRemoteCommands,
      ),
      snapshot: sourceLink.snapshot!,
    );

    // Offer -> target.
    network.deliverHeld();
    await settle();
    // Readiness -> source. The source commits and stops.
    network.deliverHeld();
    await settle();
    expect(sourceEngine.calls, contains('pause'));
    // Commit -> target. It actually starts playing and composes its
    // result, but the result stays held rather than reaching the
    // source yet.
    network.deliverHeld();
    await settle();
    expect(targetEngine.playing, isTrue);

    // The source's wait for that result runs out before it is
    // delivered — a lost acknowledgement, exactly the arc's hardest
    // invariant.
    final result = await resultFuture;
    expect(result.isErr, isTrue);
    expect(sourcePlayback.state.isPlaying, isTrue, reason: 'resumed');

    // The result that was actually sent arrives after all.
    network.deliverHeld();
    await settle();

    // Two players for a moment; the loser is this device, since the
    // target genuinely owns it now.
    expect(sourceEngine.playing, isFalse);
    expect(targetEngine.playing, isTrue);
  });
}
