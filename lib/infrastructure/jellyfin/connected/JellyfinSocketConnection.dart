import 'dart:async';
import 'dart:io';

/// One open Jellyfin WebSocket, reduced to what connected playback needs:
/// text frames in, text frames out, and an end.
///
/// The seam exists for the same reason `MediaHttpClientFactory` does —
/// so the transport above it can be tested without a server — and it is
/// narrow enough that the fake in the tests is a `StreamController` and a
/// list. Anything richer would be a fake worth doubting.
abstract class JellyfinSocketConnection {
  /// Text frames from the server. Closes when the socket does; errors on
  /// it are the socket dying, which the transport treats as an
  /// interruption to reconnect from.
  Stream<String> get messages;

  /// Sends one text frame. Throws if the socket has already gone; the
  /// caller is expected to be inside the transport's own error handling.
  void send(String message);

  Future<void> close();
}

/// Opens a socket to [url]. Injected, so nothing above has to know that
/// the production implementation is `dart:io`.
typedef JellyfinSocketConnector =
    Future<JellyfinSocketConnection> Function(Uri url);

/// The production connector: `dart:io`'s own WebSocket.
///
/// A built-in rather than a package, deliberately. `CONTEXT.md` asks that
/// dependencies "handle substantial infrastructure work" and not
/// "substitute for trivial local code": the whole implementation is the
/// twenty lines below, and it works on every target Jellyfinity ships to
/// — Android, Windows and iOS all have `dart:io`. Jellyfinity has no web
/// target, which is the one place this choice would be wrong.
class IoJellyfinSocketConnection implements JellyfinSocketConnection {
  IoJellyfinSocketConnection(this._socket);

  /// Connects, or throws — `WebSocketException` when the server answered
  /// but would not upgrade (the reverse-proxy case), `SocketException`
  /// when it could not be reached at all. The transport tells those two
  /// apart; see `ConnectedPlaybackFailures`.
  static Future<JellyfinSocketConnection> connect(Uri url) async {
    final socket = await WebSocket.connect(url.toString());
    return IoJellyfinSocketConnection(socket);
  }

  final WebSocket _socket;

  @override
  Stream<String> get messages =>
      _socket.where((frame) => frame is String).cast<String>();

  @override
  void send(String message) => _socket.add(message);

  @override
  Future<void> close() async {
    await _socket.close(WebSocketStatus.normalClosure);
  }
}
