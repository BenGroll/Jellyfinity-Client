import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'ConnectedPlaybackLimits.dart';
import 'ConnectedPlaybackScope.dart';
import 'ProtocolVersion.dart';
import 'envelope_ignore_reason.dart';
import 'envelope_kind.dart';

/// The one shape every Jellyfinity-to-Jellyfinity message has.
///
/// Jellyfin's remote-control channel carries opaque payloads between
/// sessions; it has no opinion about what two clients say to each other.
/// That freedom is exactly why the envelope has to be strict. Everything
/// needed to decide *whether to read a message at all* lives in the
/// envelope and is checked before the payload is looked at:
///
/// 1. Size, before parsing — an oversized message costs nothing to drop.
/// 2. [protocolVersion] — a different major version is an incompatible
///    peer, surfaced, never parsed.
/// 3. [scope] — a different server or profile is dropped unread, which is
///    the account-isolation invariant enforced at the earliest possible
///    point rather than by each handler remembering to check.
/// 4. [senderSessionId] against this session — Jellyfin broadcasts to
///    every session including the sender, and a device that acted on its
///    own commands would apply each of them twice.
/// 5. [kind] — an unknown kind is a newer peer's new feature and is
///    ignored, not an error.
///
/// Only then does the [payload] matter, and a handler that cannot make
/// sense of it still answers rather than throwing. [decode] has no
/// throwing path at all: everything it cannot use comes back as an
/// [IgnoredEnvelope] with a reason.
class ConnectedPlaybackEnvelope extends Equatable {
  const ConnectedPlaybackEnvelope({
    required this.messageId,
    required this.protocolVersion,
    required this.scope,
    required this.senderSessionId,
    required this.kind,
    this.payload = const {},
  });

  /// Builds an envelope from this build, at [ProtocolVersion.current].
  factory ConnectedPlaybackEnvelope.outgoing({
    required String messageId,
    required ConnectedPlaybackScope scope,
    required String senderSessionId,
    required EnvelopeKind kind,
    Map<String, Object?> payload = const {},
  }) => ConnectedPlaybackEnvelope(
    messageId: messageId,
    protocolVersion: ProtocolVersion.current,
    scope: scope,
    senderSessionId: senderSessionId,
    kind: kind,
    payload: payload,
  );

  /// Unique per message. Distinct from a command's own id: one command
  /// retried three times is three messages carrying one command id, and
  /// deduplicating on the wrong one of the two either drops the retry or
  /// applies the command three times.
  final String messageId;

  final ProtocolVersion protocolVersion;
  final ConnectedPlaybackScope scope;

  /// The session that sent this.
  final String senderSessionId;

  final EnvelopeKind kind;

  /// The kind-specific body. Unknown keys inside it are preserved on
  /// decode and ignored on use, so a newer peer's extra fields survive a
  /// round trip through an older build rather than being stripped.
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'v': protocolVersion.toString(),
    'id': messageId,
    'scope': scope.key,
    'from': senderSessionId,
    'kind': kind.wireName,
    'payload': payload,
  };

  String encode() => jsonEncode(toJson());

  /// Reads an arriving message.
  ///
  /// [raw] is whatever the transport handed over — the JSON string from a
  /// WebSocket frame, or an already-parsed map from a REST response.
  /// [localScope] and [localSessionId] are this device's own; both
  /// checks belong here rather than in a handler, for the reason in the
  /// class comment.
  ///
  /// Never throws.
  static EnvelopeDecoding decode(
    Object? raw, {
    required ConnectedPlaybackScope localScope,
    required String localSessionId,
    ProtocolVersion localVersion = ProtocolVersion.current,
  }) {
    final Object? decoded;
    if (raw is String) {
      if (raw.length > ConnectedPlaybackLimits.maxPayloadBytes) {
        return const IgnoredEnvelope(
          EnvelopeIgnoreReason.tooLarge,
          'message exceeds the payload bound',
        );
      }
      try {
        decoded = jsonDecode(raw);
      } on FormatException catch (error) {
        return IgnoredEnvelope(
          EnvelopeIgnoreReason.malformed,
          'not JSON (${error.message})',
        );
      }
    } else {
      decoded = raw;
    }

    if (decoded is! Map) {
      return const IgnoredEnvelope(
        EnvelopeIgnoreReason.malformed,
        'not a JSON object',
      );
    }

    final version = ProtocolVersion.tryParse(_stringOrNull(decoded['v']));
    if (version == null) {
      return const IgnoredEnvelope(
        EnvelopeIgnoreReason.malformed,
        'missing or unreadable protocol version',
      );
    }
    if (!version.isCompatibleWith(localVersion)) {
      return IgnoredEnvelope(
        EnvelopeIgnoreReason.incompatibleProtocol,
        'peer speaks protocol $version',
        protocolVersion: version,
        senderSessionId: _stringOrNull(decoded['from']),
      );
    }

    final scope = ConnectedPlaybackScope.tryParse(
      _stringOrNull(decoded['scope']),
    );
    if (scope == null) {
      return const IgnoredEnvelope(
        EnvelopeIgnoreReason.malformed,
        'missing or unreadable scope',
      );
    }
    if (scope != localScope) {
      return const IgnoredEnvelope(
        EnvelopeIgnoreReason.outOfScope,
        'message belongs to another server or profile',
      );
    }

    final messageId = _stringOrNull(decoded['id']);
    final sender = _stringOrNull(decoded['from']);
    if (messageId == null || sender == null) {
      return const IgnoredEnvelope(
        EnvelopeIgnoreReason.malformed,
        'missing message id or sender',
      );
    }
    if (sender == localSessionId) {
      return const IgnoredEnvelope(
        EnvelopeIgnoreReason.fromSelf,
        'this session sent this message',
      );
    }

    final kind = EnvelopeKind.tryParse(decoded['kind']);
    if (kind == null) {
      return IgnoredEnvelope(
        EnvelopeIgnoreReason.unknownKind,
        'unknown message kind ${decoded['kind']}',
        protocolVersion: version,
        senderSessionId: sender,
      );
    }

    final payload = decoded['payload'];
    return DecodedEnvelope(
      ConnectedPlaybackEnvelope(
        messageId: messageId,
        protocolVersion: version,
        scope: scope,
        senderSessionId: sender,
        kind: kind,
        payload: payload is Map
            ? {
                for (final entry in payload.entries)
                  entry.key.toString(): entry.value,
              }
            : const {},
      ),
    );
  }

  static String? _stringOrNull(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  @override
  List<Object?> get props => [
    messageId,
    protocolVersion,
    scope,
    senderSessionId,
    kind,
    payload,
  ];
}

/// The result of [ConnectedPlaybackEnvelope.decode].
///
/// A sealed pair rather than a `Result`, because an ignored message is
/// not a failure: most of the traffic on a shared server channel is not
/// addressed to this conversation, and treating "not for me" as an error
/// would fill the logs with alarm about the normal case.
sealed class EnvelopeDecoding {
  const EnvelopeDecoding();
}

final class DecodedEnvelope extends EnvelopeDecoding {
  const DecodedEnvelope(this.envelope);

  final ConnectedPlaybackEnvelope envelope;
}

final class IgnoredEnvelope extends EnvelopeDecoding {
  const IgnoredEnvelope(
    this.reason,
    this.detail, {
    this.protocolVersion,
    this.senderSessionId,
  });

  final EnvelopeIgnoreReason reason;

  /// A short log-presentable explanation. Never a payload dump.
  final String detail;

  /// The peer's version, when it was readable — what an incompatible
  /// device row shows.
  final ProtocolVersion? protocolVersion;

  /// The peer's session, when it was readable, so an incompatible device
  /// can be attributed to a row in the picker.
  final String? senderSessionId;
}
