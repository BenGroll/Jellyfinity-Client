import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackLimits.dart';
import 'package:jellyfinity/domain/connected_playback/PlaybackTransfer.dart';
import 'package:jellyfinity/domain/connected_playback/StateRevision.dart';
import 'package:jellyfinity/domain/connected_playback/transfer_refusal.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';

import '../../support/connected_playback/connected_playback_fixtures.dart';

/// v0.5.4 wire-frames the four handoff messages `PlaybackTransfer.dart`
/// already defined in v0.5.1. Every field the pure conversation carries
/// has to survive a round trip through JSON, or a real handoff would
/// silently lose whatever the codec dropped.
void main() {
  group('TransferOffer', () {
    test('round-trips every field it carries', () {
      final offer = TransferOffer(
        transferId: 'transfer-1',
        scope: testScope,
        sourceSessionId: 'session-phone',
        targetSessionId: 'session-tv',
        entries: entries(3),
        startIndex: 1,
        startPosition: const Duration(seconds: 42),
        shuffleEnabled: true,
        repeatMode: RepeatMode.all,
        originName: 'Late Night',
        startPlaying: false,
        lifetime: const Duration(seconds: 25),
      );

      final decoded = TransferOfferCodec.tryDecode(
        jsonDecode(jsonEncode(offer.toPayload())) as Map<String, Object?>,
        scope: testScope,
        sourceSessionId: 'session-phone',
      );

      expect(decoded, offer);
    });

    test('defaults startPlaying to true when the field is absent', () {
      // An older peer's payload predates the field; treating its absence
      // as "playing" matches every offer this build itself sends by
      // default and never invents a paused transfer nobody asked for.
      final payload = TransferOffer(
        transferId: 't',
        scope: testScope,
        sourceSessionId: 'session-phone',
        targetSessionId: 'session-tv',
        entries: entries(1),
        startIndex: 0,
      ).toPayload()..remove('startPlaying');

      final decoded = TransferOfferCodec.tryDecode(
        payload,
        scope: testScope,
        sourceSessionId: 'session-phone',
      );

      expect(decoded!.startPlaying, isTrue);
    });

    test('refuses a payload with no entries rather than an empty offer', () {
      expect(
        TransferOfferCodec.tryDecode(
          const {'transferId': 't', 'target': 's', 'startIndex': 0},
          scope: testScope,
          sourceSessionId: 'session-phone',
        ),
        isNull,
      );
    });

    test('refuses an unreadable entry instead of dropping just that one', () {
      final payload = TransferOffer(
        transferId: 't',
        scope: testScope,
        sourceSessionId: 'session-phone',
        targetSessionId: 'session-tv',
        entries: entries(2),
        startIndex: 0,
      ).toPayload();
      payload['entries'] = [...payload['entries']! as List, 'not an entry'];

      expect(
        TransferOfferCodec.tryDecode(
          payload,
          scope: testScope,
          sourceSessionId: 'session-phone',
        ),
        isNull,
      );
    });
  });

  group('TransferReadiness', () {
    test('a ready answer round-trips', () {
      final readiness = TransferReadiness.ready(
        transferId: 'transfer-1',
        targetSessionId: 'session-tv',
      );

      final decoded = TransferReadinessCodec.tryDecode(
        jsonDecode(jsonEncode(readiness.toPayload())) as Map<String, Object?>,
        targetSessionId: 'session-tv',
      );

      expect(decoded, readiness);
    });

    test(
      'a refusal round-trips its unresolvable entries and their position',
      () {
        final readiness = TransferReadiness.refused(
          transferId: 'transfer-1',
          targetSessionId: 'session-tv',
          refusal: TransferRefusal.localOnlyItems,
          unresolvable: const [
            UnavailableItem(
              id: 'server-1:t0',
              reason: 'Not on this device',
              position: 0,
            ),
            UnavailableItem(
              id: 'server-1:t2',
              reason: 'Not on this device',
              position: 2,
            ),
          ],
          message: 'Two songs are not on that device.',
        );

        final decoded = TransferReadinessCodec.tryDecode(
          jsonDecode(jsonEncode(readiness.toPayload())) as Map<String, Object?>,
          targetSessionId: 'session-tv',
        );

        expect(decoded, readiness);
      },
    );
  });

  group('TransferCommit', () {
    test('round-trips its position', () {
      const commit = TransferCommit(
        transferId: 'transfer-1',
        sourceSessionId: 'session-phone',
        targetSessionId: 'session-tv',
        position: Duration(seconds: 47),
      );

      final decoded = TransferCommitCodec.tryDecode(
        jsonDecode(jsonEncode(commit.toPayload())) as Map<String, Object?>,
        sourceSessionId: 'session-phone',
        targetSessionId: 'session-tv',
      );

      expect(decoded, commit);
    });
  });

  group('TransferResult', () {
    test('an accepted result round-trips its revision', () {
      final result = TransferResult.playing(
        transferId: 'transfer-1',
        targetSessionId: 'session-tv',
        revision: const StateRevision(3),
      );

      final decoded = TransferResultCodec.tryDecode(
        jsonDecode(jsonEncode(result.toPayload())) as Map<String, Object?>,
        targetSessionId: 'session-tv',
      );

      expect(decoded, result);
    });

    test('a failed result round-trips its refusal', () {
      final result = TransferResult.failed(
        transferId: 'transfer-1',
        targetSessionId: 'session-tv',
        refusal: TransferRefusal.playbackFailed,
        message: 'Could not start playing.',
      );

      final decoded = TransferResultCodec.tryDecode(
        jsonDecode(jsonEncode(result.toPayload())) as Map<String, Object?>,
        targetSessionId: 'session-tv',
      );

      expect(decoded, result);
    });

    test('an accepted result missing its revision is unreadable', () {
      expect(
        TransferResultCodec.tryDecode(const {
          'transferId': 't',
          'accepted': true,
        }, targetSessionId: 'session-tv'),
        isNull,
      );
    });
  });

  test(
    'a lifetime survives the round trip, defaulting to the shared step timeout',
    () {
      final payload = TransferOffer(
        transferId: 't',
        scope: testScope,
        sourceSessionId: 'session-phone',
        targetSessionId: 'session-tv',
        entries: entries(1),
        startIndex: 0,
      ).toPayload()..remove('lifetimeMs');

      final decoded = TransferOfferCodec.tryDecode(
        payload,
        scope: testScope,
        sourceSessionId: 'session-phone',
      );

      expect(decoded!.lifetime, ConnectedPlaybackLimits.handoffStepTimeout);
    },
  );
}
