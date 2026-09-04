import 'package:injectable/injectable.dart';

import '../persistence/device_identity_store.dart';
import 'identity/JellyfinClientIdentity.dart';

/// DI wiring for values in the Jellyfin transport layer that are built
/// from construction logic rather than plain constructor injection.
///
/// [JellyfinClientIdentity] needs a stable device id. From v0.0.6 that id
/// is persisted (ADR-0010), so the identity is resolved asynchronously
/// from [DeviceIdentityStore] and `@preResolve`d — `configureDependencies()`
/// reads (or, on first ever launch, generates and writes) the id before
/// the graph is handed out, so every request reports the same device.
@module
abstract class JellyfinTransportModule {
  @preResolve
  @lazySingleton
  Future<JellyfinClientIdentity> clientIdentity(
    DeviceIdentityStore deviceIdentity,
  ) async => JellyfinClientIdentity.forThisApp(
    deviceId: await deviceIdentity.deviceId(),
  );
}
