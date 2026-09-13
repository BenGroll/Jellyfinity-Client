import 'package:injectable/injectable.dart';

import '../../domain/connected_playback/ConnectedPlaybackTransport.dart';
import '../../domain/connected_playback/DevicePresenceSource.dart';
import '../../infrastructure/jellyfin/connected/JellyfinSessionTransport.dart';

/// Exposes the one [JellyfinSessionTransport] singleton under both of
/// v0.5.1's contracts as well as its concrete type.
///
/// [JellyfinSessionTransport] itself stays a plain `@lazySingleton` —
/// `ConnectedPlaybackLink` needs concrete-only lifecycle members
/// (`advertise`, `clear`, `platformName`, `capabilities`) that are not
/// part of either contract. `ConnectedPlaybackTargetLink` and
/// `ConnectedPlaybackControllerSession` (v0.5.3) need only
/// [ConnectedPlaybackTransport]'s send/receive seam; the device picker
/// (v0.5.5) needs only [DevicePresenceSource]'s read model. Binding the
/// *existing* singleton to each interface here — rather than annotating
/// the class itself with `@LazySingleton(as: ...)`, which only supports
/// one contract — keeps every call site resolving the same live
/// connection instead of risking independently constructed transports
/// racing to open the same socket.
@module
abstract class ConnectedPlaybackTransportModule {
  @lazySingleton
  ConnectedPlaybackTransport transport(JellyfinSessionTransport transport) =>
      transport;

  @lazySingleton
  DevicePresenceSource presenceSource(JellyfinSessionTransport transport) =>
      transport;
}
