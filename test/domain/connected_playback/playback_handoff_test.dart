import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackLimits.dart';
import 'package:jellyfinity/domain/connected_playback/PlaybackHandoff.dart';
import 'package:jellyfinity/domain/connected_playback/PlaybackTransfer.dart';
import 'package:jellyfinity/domain/connected_playback/StateRevision.dart';
import 'package:jellyfinity/domain/connected_playback/transfer_refusal.dart';
import 'package:jellyfinity/domain/connected_playback/transfer_stage.dart';

import '../../support/connected_playback/FakeElapsedClock.dart';
import '../../support/connected_playback/connected_playback_fixtures.dart';

/// The handoff's safety property is a negative one — two devices must
/// never both keep playing, and the listener must never be left with
/// neither. Every branch out of the uncertain window is exercised here,
/// including the lost acknowledgement that is close to unprovokable on
/// real hardware.
void main() {
  late FakeElapsedClock clock;
  late PlaybackHandoff handoff;

  const resumeState = HandoffResumeState(
    currentIndex: 2,
    position: Duration(seconds: 45),
    wasPlaying: true,
  );

  TransferOffer offer({int entryCount = 3, int startIndex = 0}) =>
      TransferOffer(
        transferId: 'transfer-1',
        scope: testScope,
        sourceSessionId: 'session-phone',
        targetSessionId: 'session-tv',
        entries: entries(entryCount),
        startIndex: startIndex,
        startPosition: const Duration(seconds: 45),
      );

  setUp(() {
    clock = FakeElapsedClock();
    handoff = PlaybackHandoff(clock: clock);
  });

  group('the source keeps playing until it commits', () {
    test('offering does not stop local playback', () {
      final decision = handoff.begin(offer(), resumeState);

      expect(decision.action, HandoffAction.sendOffer);
      expect(handoff.stage, TransferStage.offering);
      expect(handoff.stage.sourceStillOwnsPlayback, isTrue);
    });

    test('a refusal costs the listener nothing but an explanation', () {
      handoff.begin(offer(), resumeState);

      final decision = handoff.onReadiness(
        TransferReadiness.refused(
          transferId: 'transfer-1',
          targetSessionId: 'session-tv',
          refusal: TransferRefusal.localOnlyItems,
          unresolvable: const [
            UnavailableItem(
              id: 'server-1:t1',
              reason: 'Only on this device',
              position: 1,
            ),
          ],
        ),
      );

      // No resume needed: playback never stopped.
      expect(decision.action, HandoffAction.none);
      expect(decision.refusal, TransferRefusal.localOnlyItems);
      expect(handoff.stage, TransferStage.resumedAtSource);
      expect(handoff.stage.sourceStillOwnsPlayback, isTrue);
    });

    test('refuses an over-long queue before anything happens', () {
      final decision = handoff.begin(
        TransferOffer(
          transferId: 'transfer-1',
          scope: testScope,
          sourceSessionId: 'session-phone',
          targetSessionId: 'session-tv',
          entries: entries(ConnectedPlaybackLimits.maxQueueEntries + 1),
          startIndex: 0,
        ),
        resumeState,
      );

      expect(decision.refusal, TransferRefusal.queueTooLarge);
      expect(handoff.stage, TransferStage.resumedAtSource);
    });

    test('refuses a second handoff while one is in flight', () {
      handoff.begin(offer(), resumeState);

      final decision = handoff.begin(offer(), resumeState);

      expect(decision.refusal, TransferRefusal.busy);
      expect(handoff.stage, TransferStage.offering);
    });
  });

  group('the happy path', () {
    test('prepare, commit, acknowledge, become a controller', () {
      handoff.begin(offer(), resumeState);

      final prepared = handoff.onReadiness(
        TransferReadiness.ready(
          transferId: 'transfer-1',
          targetSessionId: 'session-tv',
        ),
      );
      expect(prepared.action, HandoffAction.commit);
      expect(handoff.stage, TransferStage.prepared);

      final committed = handoff.commit();
      expect(committed.action, HandoffAction.stopLocalPlayback);
      expect(handoff.stage, TransferStage.committing);
      expect(handoff.stage.sourceStillOwnsPlayback, isFalse);

      final finished = handoff.onResult(
        TransferResult.playing(
          transferId: 'transfer-1',
          targetSessionId: 'session-tv',
          revision: const StateRevision(3),
        ),
      );

      expect(finished.action, HandoffAction.becomeController);
      expect(handoff.stage, TransferStage.completed);
      // The baseline for controlling the new owner, without another
      // round trip.
      expect(handoff.targetRevision, const StateRevision(3));
    });
  });

  group('the uncertain window', () {
    test('a lost acknowledgement resumes the source', () {
      handoff.begin(offer(), resumeState);
      handoff.onReadiness(
        TransferReadiness.ready(
          transferId: 'transfer-1',
          targetSessionId: 'session-tv',
        ),
      );
      handoff.commit();

      clock.advance(ConnectedPlaybackLimits.handoffStepTimeout * 2);
      expect(handoff.expired, isTrue);

      final decision = handoff.onTimeout();

      // The listener gets their music back rather than silence.
      expect(decision.action, HandoffAction.resumeLocalPlayback);
      expect(decision.resumeState, resumeState);
      expect(decision.refusal, TransferRefusal.timedOut);
      expect(handoff.stage, TransferStage.resumedAtSource);
    });

    test('a late acknowledgement stops the resumed source', () {
      handoff.begin(offer(), resumeState);
      handoff.onReadiness(
        TransferReadiness.ready(
          transferId: 'transfer-1',
          targetSessionId: 'session-tv',
        ),
      );
      handoff.commit();
      handoff.onTimeout();

      final decision = handoff.onLateResult(
        TransferResult.playing(
          transferId: 'transfer-1',
          targetSessionId: 'session-tv',
          revision: const StateRevision(3),
        ),
      );

      // The target did start after all, so this device is the one that
      // must stop. Two players resolve to one, always.
      expect(decision.action, HandoffAction.stopLocalPlayback);
      expect(handoff.stage, TransferStage.completed);
    });

    test('a target that could not start hands playback back', () {
      handoff.begin(offer(), resumeState);
      handoff.onReadiness(
        TransferReadiness.ready(
          transferId: 'transfer-1',
          targetSessionId: 'session-tv',
        ),
      );
      handoff.commit();

      final decision = handoff.onResult(
        TransferResult.failed(
          transferId: 'transfer-1',
          targetSessionId: 'session-tv',
          refusal: TransferRefusal.playbackFailed,
        ),
      );

      expect(decision.action, HandoffAction.resumeLocalPlayback);
      expect(decision.resumeState, resumeState);
      expect(handoff.stage, TransferStage.resumedAtSource);
    });

    test(
      'a timeout before the commit resumes nothing, because nothing stopped',
      () {
        handoff.begin(offer(), resumeState);

        clock.advance(ConnectedPlaybackLimits.handoffStepTimeout * 2);
        final decision = handoff.onTimeout();

        expect(decision.action, HandoffAction.none);
        expect(decision.refusal, TransferRefusal.timedOut);
      },
    );

    test('cancelling is impossible once ownership is in flight', () {
      handoff.begin(offer(), resumeState);
      handoff.onReadiness(
        TransferReadiness.ready(
          transferId: 'transfer-1',
          targetSessionId: 'session-tv',
        ),
      );
      handoff.commit();

      final decision = handoff.cancel();

      expect(decision.action, HandoffAction.none);
      expect(handoff.stage, TransferStage.committing);
    });

    test('cancelling before the commit is free', () {
      handoff.begin(offer(), resumeState);

      final decision = handoff.cancel();

      expect(decision.action, HandoffAction.none);
      expect(decision.refusal, TransferRefusal.cancelled);
      expect(handoff.stage.sourceStillOwnsPlayback, isTrue);
    });
  });

  group('stray messages', () {
    test('ignores a readiness for a different transfer', () {
      handoff.begin(offer(), resumeState);

      final decision = handoff.onReadiness(
        TransferReadiness.ready(
          transferId: 'transfer-other',
          targetSessionId: 'session-tv',
        ),
      );

      expect(decision.action, HandoffAction.none);
      expect(handoff.stage, TransferStage.offering);
    });

    test('ignores a result that arrives before the commit', () {
      handoff.begin(offer(), resumeState);

      final decision = handoff.onResult(
        TransferResult.playing(
          transferId: 'transfer-1',
          targetSessionId: 'session-tv',
          revision: const StateRevision(1),
        ),
      );

      expect(decision.action, HandoffAction.none);
      expect(handoff.stage, TransferStage.offering);
    });

    test('a finished handoff never expires', () {
      handoff.begin(offer(), resumeState);
      handoff.cancel();

      clock.advance(const Duration(hours: 1));

      expect(handoff.expired, isFalse);
    });
  });

  group('refusals', () {
    test('separates the ones worth retrying from the ones that are not', () {
      expect(TransferRefusal.localOnlyItems.isRetryable, isFalse);
      expect(TransferRefusal.queueTooLarge.isRetryable, isFalse);
      expect(TransferRefusal.incompatible.isRetryable, isFalse);
      expect(TransferRefusal.notPermitted.isRetryable, isFalse);
      expect(TransferRefusal.serverUnreachable.isRetryable, isTrue);
      expect(TransferRefusal.timedOut.isRetryable, isTrue);
    });
  });
}
