import 'package:injectable/injectable.dart';

import '../../domain/connected_playback/ConnectedPlaybackTransport.dart';
import '../../infrastructure/jellyfin/connected/JellyfinSessionTransport.dart';

/// Exposes the one [JellyfinSessionTransport] singleton under its
/// [ConnectedPlaybackTransport] contract as well as its concrete type.
///
/// [JellyfinSessionTransport] itself stays a plain `@lazySingleton` —
/// `ConnectedPlaybackLink` needs concrete-only lifecycle members
/// (`advertise`, `clear`, `platformName`, `capabilities`) that are not
/// part of either of v0.5.1's contracts. `ConnectedPlaybackTargetLink`
/// and `ConnectedPlaybackControllerSession` (v0.5.3) need none of that:
/// they only send and receive envelopes, which is exactly the narrow
/// abstract seam the contract tests already drive with an in-memory
/// fake. Binding the *existing* singleton to the interface here — rather
/// than annotating the class itself with `@LazySingleton(as: ...)` —
/// keeps both call sites resolving the same live connection instead of
/// risking two independently constructed transports racing to open the
/// same socket.
@module
abstract class ConnectedPlaybackTransportModule {
  @lazySingleton
  ConnectedPlaybackTransport transport(JellyfinSessionTransport transport) =>
      transport;
}
