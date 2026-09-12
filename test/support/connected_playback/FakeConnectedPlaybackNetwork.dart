import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackEnvelope.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackScope.dart';
import 'package:jellyfinity/domain/connected_playback/ProtocolVersion.dart';

/// A deterministic stand-in for the Jellyfin relay.
///
/// It is deliberately a *bad* network, because the arc's invariants are
/// all about what happens when delivery misbehaves: "targets process
/// duplicates once, serialize competing controllers, acknowledge the
/// resulting revision, and reject stale structural mutations". A fake
/// that always delivers exactly once, in order, would pass every one of
/// those requirements without testing any of them.
///
/// So it can duplicate ([duplicates]), reorder ([reverseDelivery]), drop
/// ([dropNextSend]) and hold messages ([manualDelivery]) — all without a
/// timer, a real socket or a `Future.delayed`, so every test is exact and
/// none of them can flake.
///
/// Messages travel as encoded JSON strings rather than as objects. That
/// is not ceremony: it means every contract test also exercises the wire
/// codec, so a field that fails to survive a round trip fails a behaviour
/// test rather than only a serialization one.
class FakeConnectedPlaybackNetwork {
  final Map<String, _Node> _nodes = {};
  final List<_Message> _held = [];

  /// Extra copies of each sent message. `1` delivers everything twice.
  int duplicates = 0;

  /// Holds messages until [deliverHeld] instead of delivering them as
  /// they are sent.
  bool manualDelivery = false;

  /// Delivers held messages newest-first.
  bool reverseDelivery = false;

  /// Silently drops the next message sent — a lost frame.
  bool dropNextSend = false;

  /// Every envelope a node actually acted on, in delivery order.
  final List<ConnectedPlaybackEnvelope> delivered = [];

  /// Every envelope a node refused to act on, with the reason.
  final List<IgnoredEnvelope> ignored = [];

  void connect(
    String sessionId, {
    required ConnectedPlaybackScope scope,
    required void Function(ConnectedPlaybackEnvelope envelope) onEnvelope,
    ProtocolVersion version = ProtocolVersion.current,
  }) {
    _nodes[sessionId] = _Node(
      scope: scope,
      version: version,
      onEnvelope: onEnvelope,
    );
  }

  void disconnect(String sessionId) => _nodes.remove(sessionId);

  /// Sends [envelope] to [to], applying whichever faults are switched on.
  void send(ConnectedPlaybackEnvelope envelope, {required String to}) {
    if (dropNextSend) {
      dropNextSend = false;
      return;
    }
    final copies = 1 + duplicates;
    for (var i = 0; i < copies; i++) {
      final message = _Message(payload: envelope.encode(), to: to);
      if (manualDelivery) {
        _held.add(message);
      } else {
        _route(message);
      }
    }
  }

  /// Flushes everything held, in [reverseDelivery] order.
  void deliverHeld() {
    final pending = reverseDelivery ? _held.reversed.toList() : [..._held];
    _held.clear();
    for (final message in pending) {
      _route(message);
    }
  }

  /// Messages sent but not yet delivered.
  int get heldCount => _held.length;

  void _route(_Message message) {
    final node = _nodes[message.to];
    if (node == null) return;
    final decoding = ConnectedPlaybackEnvelope.decode(
      message.payload,
      localScope: node.scope,
      localSessionId: message.to,
      localVersion: node.version,
    );
    switch (decoding) {
      case DecodedEnvelope(:final envelope):
        delivered.add(envelope);
        node.onEnvelope(envelope);
      case IgnoredEnvelope():
        ignored.add(decoding);
    }
  }
}

class _Node {
  _Node({required this.scope, required this.version, required this.onEnvelope});

  final ConnectedPlaybackScope scope;
  final ProtocolVersion version;
  final void Function(ConnectedPlaybackEnvelope envelope) onEnvelope;
}

class _Message {
  _Message({required this.payload, required this.to});

  final String payload;
  final String to;
}
