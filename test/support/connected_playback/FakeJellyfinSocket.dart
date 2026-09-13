import 'dart:async';
import 'dart:convert';

import 'package:jellyfinity/infrastructure/jellyfin/connected/JellyfinSocketConnection.dart';

/// A Jellyfin WebSocket the test drives by hand.
///
/// The seam it satisfies is small enough that this is the whole fake: a
/// controller for what the server says, a list of what the client said,
/// and a way to kill the connection. Anything richer would be a fake
/// worth doubting.
class FakeJellyfinSocket implements JellyfinSocketConnection {
  final StreamController<String> _incoming = StreamController<String>();

  /// Every frame the client sent, in order.
  final List<String> sent = [];

  bool closed = false;

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String message) {
    if (closed) throw StateError('the socket is closed');
    sent.add(message);
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!_incoming.isClosed) await _incoming.close();
  }

  /// Delivers one server frame.
  void emit(Object message) {
    if (_incoming.isClosed) return;
    _incoming.add(message is String ? message : jsonEncode(message));
  }

  /// Jellyfin's `Sessions` push.
  void emitSessions(List<Map<String, Object?>> sessions) =>
      emit({'MessageType': 'Sessions', 'Data': sessions});

  /// A Jellyfinity envelope arriving inside the general command that
  /// carries them.
  void emitEnvelope(String encodedEnvelope, {String name = 'SendString'}) =>
      emit({
        'MessageType': 'GeneralCommand',
        'Data': {
          'Name': name,
          'Arguments': {'String': encodedEnvelope},
        },
      });

  /// The socket dying without being closed politely — a dropped network,
  /// a restarted server.
  Future<void> drop() async {
    closed = true;
    if (!_incoming.isClosed) {
      _incoming.addError(const SocketDropped());
      await _incoming.close();
    }
  }

  /// Whether the client asked the server to push session changes. Without
  /// it the socket is open and silent.
  bool get subscribedToSessions => sent.any(
    (frame) =>
        jsonDecode(frame) is Map &&
        (jsonDecode(frame) as Map)['MessageType'] == 'SessionsStart',
  );
}

/// The error a dropped socket surfaces. A named type so a test reads as
/// what it is rather than as a bare `Exception('boom')`.
class SocketDropped implements Exception {
  const SocketDropped();

  @override
  String toString() => 'the socket dropped';
}
