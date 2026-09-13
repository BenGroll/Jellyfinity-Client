import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackEnvelope.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackLimits.dart';
import 'package:jellyfinity/domain/connected_playback/ProtocolVersion.dart';
import 'package:jellyfinity/domain/connected_playback/envelope_ignore_reason.dart';
import 'package:jellyfinity/domain/connected_playback/envelope_kind.dart';

import '../../support/connected_playback/connected_playback_fixtures.dart';

/// The envelope is the only thing standing between a shared server
/// channel and this client's state, so every one of its refusals is
/// tested — not just the happy path.
void main() {
  ConnectedPlaybackEnvelope outgoing({
    String id = 'm1',
    EnvelopeKind kind = EnvelopeKind.command,
    Map<String, Object?> payload = const {'command': 'play'},
  }) => ConnectedPlaybackEnvelope.outgoing(
    messageId: id,
    scope: testScope,
    senderSessionId: 'session-phone',
    kind: kind,
    payload: payload,
  );

  EnvelopeDecoding decodeAtTv(
    Object? raw, {
    ProtocolVersion version = ProtocolVersion.current,
  }) => ConnectedPlaybackEnvelope.decode(
    raw,
    localScope: testScope,
    localSessionId: 'session-tv',
    localVersion: version,
  );

  group('round trip', () {
    test('survives encoding and decoding unchanged', () {
      final envelope = outgoing(
        payload: {'command': 'seek', 'positionMs': 42000},
      );

      final decoding = decodeAtTv(envelope.encode());

      expect(decoding, isA<DecodedEnvelope>());
      expect((decoding as DecodedEnvelope).envelope, envelope);
    });

    test('keeps payload fields this build does not understand', () {
      // A newer peer's extra field must reach a handler intact rather
      // than being stripped by the decoder on the way past.
      final decoding = decodeAtTv(
        outgoing(payload: {'command': 'play', 'fadeMs': 250}).encode(),
      );

      final envelope = (decoding as DecodedEnvelope).envelope;
      expect(envelope.payload['fadeMs'], 250);
    });

    test('decodes an already-parsed map as well as a string', () {
      final envelope = outgoing();

      final decoding = decodeAtTv(envelope.toJson());

      expect((decoding as DecodedEnvelope).envelope, envelope);
    });
  });

  group('compatibility', () {
    test('accepts a compatible peer that is ahead on minor version', () {
      final ahead = ConnectedPlaybackEnvelope(
        messageId: 'm1',
        protocolVersion: ProtocolVersion(ProtocolVersion.current.major, 9),
        scope: testScope,
        senderSessionId: 'session-phone',
        kind: EnvelopeKind.command,
        payload: const {'command': 'play'},
      );

      expect(decodeAtTv(ahead.encode()), isA<DecodedEnvelope>());
    });

    test('refuses a different major version and says who sent it', () {
      final future = ConnectedPlaybackEnvelope(
        messageId: 'm1',
        protocolVersion: const ProtocolVersion(99, 0),
        scope: testScope,
        senderSessionId: 'session-phone',
        kind: EnvelopeKind.command,
        payload: const {'command': 'play'},
      );

      final decoding = decodeAtTv(future.encode()) as IgnoredEnvelope;

      expect(decoding.reason, EnvelopeIgnoreReason.incompatibleProtocol);
      // The device row needs both of these to explain itself.
      expect(decoding.protocolVersion, const ProtocolVersion(99, 0));
      expect(decoding.senderSessionId, 'session-phone');
      expect(decoding.reason.isUserVisible, isTrue);
    });

    test('ignores a message kind it has never heard of', () {
      final decoding = decodeAtTv(
        '{"v":"1.0","id":"m1","scope":"${testScope.key}",'
        '"from":"session-phone","kind":"lyricsSync","payload":{}}',
      );

      expect(
        (decoding as IgnoredEnvelope).reason,
        EnvelopeIgnoreReason.unknownKind,
      );
      expect(decoding.reason.isUserVisible, isFalse);
    });
  });

  group('account isolation', () {
    test('drops a message for another profile on the same server', () {
      final other = ConnectedPlaybackEnvelope.outgoing(
        messageId: 'm1',
        scope: otherProfileScope,
        senderSessionId: 'session-phone',
        kind: EnvelopeKind.snapshot,
        payload: const {},
      );

      expect(
        (decodeAtTv(other.encode()) as IgnoredEnvelope).reason,
        EnvelopeIgnoreReason.outOfScope,
      );
    });

    test('drops a message for the same user on another server', () {
      final other = ConnectedPlaybackEnvelope.outgoing(
        messageId: 'm1',
        scope: otherServerScope,
        senderSessionId: 'session-phone',
        kind: EnvelopeKind.snapshot,
        payload: const {},
      );

      expect(
        (decodeAtTv(other.encode()) as IgnoredEnvelope).reason,
        EnvelopeIgnoreReason.outOfScope,
      );
    });

    test('drops this session own echoed message', () {
      final echoed = ConnectedPlaybackEnvelope.outgoing(
        messageId: 'm1',
        scope: testScope,
        senderSessionId: 'session-tv',
        kind: EnvelopeKind.command,
        payload: const {'command': 'play'},
      );

      expect(
        (decodeAtTv(echoed.encode()) as IgnoredEnvelope).reason,
        EnvelopeIgnoreReason.fromSelf,
      );
    });
  });

  group('malformed input', () {
    test('never throws, whatever arrives', () {
      const inputs = [
        'not json at all',
        '[]',
        '{}',
        '{"v":"nope","id":"m","scope":"a/b","from":"x","kind":"command"}',
        '{"v":"1.0","scope":"a/b","from":"x","kind":"command"}',
        '{"v":"1.0","id":"m","from":"x","kind":"command"}',
        '{"v":"1.0","id":"m","scope":"a/b","kind":"command"}',
      ];

      for (final input in inputs) {
        expect(
          decodeAtTv(input),
          isA<IgnoredEnvelope>(),
          reason: 'should ignore rather than throw: $input',
        );
      }
      expect(decodeAtTv(null), isA<IgnoredEnvelope>());
      expect(decodeAtTv(42), isA<IgnoredEnvelope>());
    });

    test('drops an oversized message before parsing it', () {
      final oversized = 'x' * (ConnectedPlaybackLimits.maxPayloadBytes + 1);

      expect(
        (decodeAtTv(oversized) as IgnoredEnvelope).reason,
        EnvelopeIgnoreReason.tooLarge,
      );
    });
  });

  group('ProtocolVersion', () {
    test('is compatible within a major version and not across one', () {
      expect(
        const ProtocolVersion(
          1,
          0,
        ).isCompatibleWith(const ProtocolVersion(1, 7)),
        isTrue,
      );
      expect(
        const ProtocolVersion(
          1,
          9,
        ).isCompatibleWith(const ProtocolVersion(2, 0)),
        isFalse,
      );
      expect(
        const ProtocolVersion(1, 4).isAheadOf(const ProtocolVersion(1, 1)),
        isTrue,
      );
    });

    test('parses only well-formed versions', () {
      expect(ProtocolVersion.tryParse('2.3'), const ProtocolVersion(2, 3));
      expect(ProtocolVersion.tryParse('1.2.3'), isNull);
      expect(ProtocolVersion.tryParse('-1.0'), isNull);
      expect(ProtocolVersion.tryParse('one.two'), isNull);
      expect(ProtocolVersion.tryParse(null), isNull);
    });
  });
}
