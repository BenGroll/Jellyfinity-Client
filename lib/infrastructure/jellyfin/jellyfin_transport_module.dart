import 'package:injectable/injectable.dart';

import 'identity/jellyfin_client_identity.dart';

/// DI wiring for values in the Jellyfin transport layer that are built
/// from construction logic rather than plain constructor injection.
///
/// [JellyfinClientIdentity] is registered here (not with an annotation on
/// the class) because building it needs a device id, and the source of
/// that id changes across milestones: an ephemeral per-launch id now, a
/// persisted stable id once the persistence layer (v0.0.6) exists. Keeping
/// it in a module means only this method changes then.
@module
abstract class JellyfinTransportModule {
  @lazySingleton
  JellyfinClientIdentity clientIdentity() =>
      JellyfinClientIdentity.forThisApp(deviceId: generateEphemeralDeviceId());
}
