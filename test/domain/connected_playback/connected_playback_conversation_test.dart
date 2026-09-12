import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackEnvelope.dart';
import 'package:jellyfinity/domain/connected_playback/PlaybackHandoff.dart';
import 'package:jellyfinity/domain/connected_playback/PlaybackTransfer.dart';
import 'package:jellyfinity/domain/connected_playback/RemotePlaybackSnapshot.dart';
import 'package:jellyfinity/domain/connected_playback/StateRevision.dart';
import 'package:jellyfinity/domain/connected_playback/command_outcome.dart';
import 'package:jellyfinity/domain/connected_playback/envelope_ignore_reason.dart';
import 'package:jellyfinity/domain/connected_playback/envelope_kind.dart';
import 'package:jellyfinity/domain/connected_playback/transfer_refusal.dart';
import 'package:jellyfinity/domain/connected_playback/transfer_stage.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';

import '../../support/connected_playback/ConnectedPlaybackHarness.dart';
import '../../support/connected_playback/FakeConnectedPlaybackNetwork.dart';
import '../../support/connected_playback/FakeElapsedClock.dart';
import '../../support/connected_playback/connected_playback_fixtures.dart';

/// v0.5.1's definition of done: the whole discovery, control,
/// synchronization and handoff conversation, between two clients, in
/// pure Dart — no widget, no audio backend, no Jellyfin server.
///
/// Every message here goes through the real envelope codec as an encoded
/// string, so these are also the round-trip tests for everything the
/// wire carries.
void main() {
  late FakeConnectedPlaybackNetwork network;
  late FakeElapsedClock clock;
  late FakeTargetNode tv;
  late FakeControllerNode phone;

  setUp(() {
    network = FakeConnectedPlaybackNetwork();
    clock = FakeElapsedClock();
    tv = FakeTargetNode(
      sessionId: 'session-tv',
      network: network,
      clock: clock,
      scope: testScope,
      initialState: RemotePlaybackSnapshot(
        scope: testScope,
        sessionId: 'session-tv',
        revision: const StateRevision(1),
        status: PlaybackStatus.playing,
        queue: entries(4),
        currentIndex: 0,
      ),
    );
    phone = FakeControllerNode(
      sessionId: 'session-phone',
      network: network,
      target: device(),
      scope: testScope,
    );
    tv.publishSnapshot(to: phone.sessionId);
  });

  group('control', () {
    test('a command crosses the wire, applies, and comes back answered', () {
      final pause = phone.controller.pause().valueOrNull!;

      phone.send(pause);

      expect(tv.snapshot.status, PlaybackStatus.paused);
      expect(phone.acknowledgements.single.outcome, CommandOutcome.applied);
      // The acknowledgement alone moves the revision the controller
      // composes against; the contents still wait for the snapshot.
      expect(phone.controller.knownRevision, tv.snapshot.revision);
    });

    test('a queue edit round-trips with its entries intact', () {
      final append = phone.controller.appendToQueue([
        entry('extra', title: 'Extra Track'),
      ]).valueOrNull!;

      phone.send(append);
      tv.publishSnapshot(to: phone.sessionId);

      expect(tv.snapshot.queue, hasLength(5));
      expect(tv.snapshot.queue.last.title, 'Extra Track');
      expect(phone.controller.projection?.queue.last.title, 'Extra Track');
    });

    test(
      'a command this build does not implement is answered, not ignored',
      () {
        // Composed by hand: an older build receiving a newer one's command
        // has to say "unsupported" rather than go silent, or the
        // controller waits out a full timeout for nothing.
        phone.sendEnvelope(EnvelopeKind.command, {
          'commandId': 'c-future',
          'target': 'session-tv',
          'command': 'setCrossfade',
          'lifetimeMs': 10000,
        });

        expect(
          phone.acknowledgements.single.outcome,
          CommandOutcome.unsupported,
        );
      },
    );
  });

  group('duplicate and reordered delivery', () {
    test('a skip duplicated by the network still costs one track', () {
      network.duplicates = 2;

      phone.send(phone.controller.next().valueOrNull!);

      expect(tv.snapshot.currentIndex, 1);
      expect(tv.sent.map((ack) => ack.outcome), [
        CommandOutcome.applied,
        CommandOutcome.duplicate,
        CommandOutcome.duplicate,
      ]);
    });

    test('snapshots arriving out of order leave the newest in place', () {
      phone.snapshots.clear();
      network.manualDelivery = true;
      tv.target.publishLocalChange(
        (current) => current.copyWith(status: PlaybackStatus.paused),
      );
      tv.publishSnapshot(to: phone.sessionId);
      tv.target.publishLocalChange(
        (current) => current.copyWith(position: const Duration(seconds: 12)),
      );
      tv.publishSnapshot(to: phone.sessionId);

      network.reverseDelivery = true;
      network.deliverHeld();

      // Both arrived; the earlier one arrived last and was dropped.
      expect(phone.snapshots, hasLength(2));
      expect(phone.controller.projection?.revision, tv.snapshot.revision);
      expect(
        phone.controller.projection?.position,
        const Duration(seconds: 12),
      );
    });

    test('a lost acknowledgement leaves the controller knowingly unsure', () {
      final pause = phone.controller.pause().valueOrNull!;
      network.dropNextSend = true;

      phone.send(pause);
      phone.controller.onTimeout();

      expect(phone.acknowledgements, isEmpty);
      expect(phone.controller.needsResync, isTrue);
      // And a structural edit is refused until it has looked again.
      expect(phone.controller.removeQueueEntry(0).isErr, isTrue);
    });
  });

  group('two controllers', () {
    late FakeControllerNode desktop;

    setUp(() {
      desktop = FakeControllerNode(
        sessionId: 'session-desktop',
        network: network,
        target: device(),
        scope: testScope,
      );
      tv.publishSnapshot(to: desktop.sessionId);
    });

    test('the second edit against one revision is refused, not applied', () {
      final phoneEdit = phone.controller.removeQueueEntry(0).valueOrNull!;
      final desktopEdit = desktop.controller.removeQueueEntry(1).valueOrNull!;

      phone.send(phoneEdit);
      desktop.send(desktopEdit);

      expect(tv.snapshot.queue, hasLength(3));
      expect(phone.acknowledgements.single.outcome, CommandOutcome.applied);
      expect(desktop.acknowledgements.single.outcome, CommandOutcome.stale);
      expect(desktop.controller.needsResync, isTrue);
    });

    test('the refused controller recovers from the snapshot it asks for', () {
      phone.send(phone.controller.removeQueueEntry(0).valueOrNull!);
      desktop.send(desktop.controller.removeQueueEntry(1).valueOrNull!);

      desktop.send(desktop.controller.requestSnapshot().valueOrNull!);
      tv.publishSnapshot(to: desktop.sessionId);

      expect(desktop.controller.needsResync, isFalse);
      expect(desktop.controller.projection?.queue, hasLength(3));
      expect(desktop.controller.removeQueueEntry(1).isOk, isTrue);
    });
  });

  group('timeouts at the target', () {
    test('a command held past its lifetime is dropped, not applied late', () {
      tv.holdCommands = true;
      phone.send(phone.controller.pause().valueOrNull!);

      clock.advance(const Duration(seconds: 30));
      tv.drain();

      expect(tv.snapshot.status, PlaybackStatus.playing);
      expect(phone.acknowledgements.single.outcome, CommandOutcome.expired);
      expect(phone.acknowledgements.single.outcome.requiresResync, isTrue);
    });
  });

  group('account isolation', () {
    test('another profile session on the same server sees nothing', () {
      final intruder = FakeControllerNode(
        sessionId: 'session-other-profile',
        network: network,
        target: device(scope: otherProfileScope),
        scope: otherProfileScope,
      );

      tv.publishSnapshot(to: intruder.sessionId);

      expect(intruder.snapshots, isEmpty);
      expect(
        network.ignored.map((ignored) => ignored.reason),
        contains(EnvelopeIgnoreReason.outOfScope),
      );
    });

    test('a command from another profile changes nothing', () {
      final intruder = FakeControllerNode(
        sessionId: 'session-other-profile',
        network: network,
        target: device(scope: otherProfileScope),
        scope: otherProfileScope,
      );

      intruder.sendEnvelope(EnvelopeKind.command, {
        'commandId': 'c-intruder',
        'target': 'session-tv',
        'command': 'stop',
        'lifetimeMs': 10000,
      });

      expect(tv.snapshot.status, PlaybackStatus.playing);
      expect(tv.sent, isEmpty);
    });
  });

  group('handoff across the wire', () {
    /// Drives the source half of a handoff with the real
    /// [PlaybackHandoff], sending and receiving real envelopes.
    PlaybackHandoff startTransfer({int entryCount = 3}) {
      final handoff = PlaybackHandoff(clock: clock);
      phone.onOtherEnvelope = (envelope) {
        switch (envelope.kind) {
          case EnvelopeKind.transferReadiness:
            handoff.onReadiness(
              envelope.payload['ready'] == true
                  ? TransferReadiness.ready(
                      transferId: envelope.payload['transferId']! as String,
                      targetSessionId: envelope.senderSessionId,
                    )
                  : TransferReadiness.refused(
                      transferId: envelope.payload['transferId']! as String,
                      targetSessionId: envelope.senderSessionId,
                      refusal: TransferRefusal.values.firstWhere(
                        (value) => value.name == envelope.payload['refusal'],
                        orElse: () => TransferRefusal.playbackFailed,
                      ),
                    ),
            );
          case EnvelopeKind.transferResult:
            final result = TransferResult.playing(
              transferId: envelope.payload['transferId']! as String,
              targetSessionId: envelope.senderSessionId,
              revision: StateRevision.tryParse(envelope.payload['revision'])!,
            );
            if (handoff.stage == TransferStage.resumedAtSource) {
              handoff.onLateResult(result);
            } else {
              handoff.onResult(result);
            }
          default:
            return;
        }
      };

      final offer = TransferOffer(
        transferId: 'transfer-1',
        scope: testScope,
        sourceSessionId: phone.sessionId,
        targetSessionId: tv.sessionId,
        entries: entries(entryCount),
        startIndex: 1,
        startPosition: const Duration(seconds: 45),
        originName: 'Late Night',
      );

      final decision = handoff.begin(
        offer,
        const HandoffResumeState(
          currentIndex: 1,
          position: Duration(seconds: 45),
          wasPlaying: true,
        ),
      );
      expect(decision.action, HandoffAction.sendOffer);

      phone.sendEnvelope(EnvelopeKind.transferOffer, {
        'transferId': offer.transferId,
        'target': offer.targetSessionId,
        'entries': [for (final entry in offer.entries) entry.toJson()],
        'startIndex': offer.startIndex,
        'startPositionMs': offer.startPosition.inMilliseconds,
        'originName': offer.originName,
      });
      return handoff;
    }

    void commit(PlaybackHandoff handoff) {
      expect(handoff.commit().action, HandoffAction.stopLocalPlayback);
      phone.sendEnvelope(EnvelopeKind.transferCommit, {
        'transferId': 'transfer-1',
        'positionMs': const Duration(seconds: 47).inMilliseconds,
      });
    }

    test('the whole queue, position and context arrive at the target', () {
      final handoff = startTransfer();

      expect(handoff.stage, TransferStage.prepared);
      commit(handoff);

      expect(handoff.stage, TransferStage.completed);
      expect(tv.snapshot.queue, hasLength(3));
      expect(tv.snapshot.currentIndex, 1);
      // Continuing the song, not restarting it.
      expect(tv.snapshot.position, const Duration(seconds: 47));
      expect(tv.snapshot.originName, 'Late Night');
      expect(tv.snapshot.status, PlaybackStatus.playing);
      expect(handoff.targetRevision, tv.snapshot.revision);
    });

    test('a refusal arrives before anything stops', () {
      tv.prepare = (offer) => TransferReadiness.refused(
        transferId: offer.transferId,
        targetSessionId: offer.targetSessionId,
        refusal: TransferRefusal.localOnlyItems,
      );

      final handoff = startTransfer();

      expect(handoff.stage, TransferStage.resumedAtSource);
      expect(handoff.refusal, TransferRefusal.localOnlyItems);
      // The target never touched its own playback.
      expect(tv.snapshot.queue, hasLength(4));
    });

    test('a lost result resumes the source, and a late one stops it again', () {
      final handoff = startTransfer();
      network.dropNextSend = true;
      commit(handoff);

      clock.advance(const Duration(minutes: 1));
      final resumed = handoff.onTimeout();

      expect(resumed.action, HandoffAction.resumeLocalPlayback);
      expect(resumed.resumeState?.position, const Duration(seconds: 45));

      // The target did start; its result was only lost. When one turns
      // up, the resumed source is the one that stops.
      final late = handoff.onLateResult(
        TransferResult.playing(
          transferId: 'transfer-1',
          targetSessionId: tv.sessionId,
          revision: tv.snapshot.revision,
        ),
      );

      expect(late.action, HandoffAction.stopLocalPlayback);
      expect(handoff.stage, TransferStage.completed);
    });
  });

  group('nothing leaks onto the wire that should not', () {
    test('a queue entry carries identifiers and metadata only', () {
      phone.send(phone.controller.requestSnapshot().valueOrNull!);
      tv.publishSnapshot(to: phone.sessionId);

      final snapshotEnvelope = network.delivered.lastWhere(
        (envelope) => envelope.kind == EnvelopeKind.snapshot,
      );
      final encoded = ConnectedPlaybackEnvelope.outgoing(
        messageId: 'probe',
        scope: snapshotEnvelope.scope,
        senderSessionId: snapshotEnvelope.senderSessionId,
        kind: snapshotEnvelope.kind,
        payload: snapshotEnvelope.payload,
      ).encode();

      // The invariant is "server-addressable music metadata and
      // identifiers" only — never a token, a stream URL or a file path.
      expect(encoded, isNot(contains('api_key')));
      expect(encoded, isNot(contains('http')));
      expect(encoded, isNot(contains('Token')));
      expect(encoded, isNot(contains('url')));
      expect(encoded, isNot(contains('path')));
      expect(encoded, isNot(contains('file')));
      expect(encoded, contains('Track t0'));
    });
  });
}
