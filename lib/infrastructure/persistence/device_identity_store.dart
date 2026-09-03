import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'key_value_store.dart';

/// Supplies the stable device identifier Jellyfinity reports to a Jellyfin
/// server on every request (the `DeviceId` field of the `Authorization`
/// header — see `JellyfinClientIdentity`).
///
/// ADR-0008 and ADR-0009 deliberately left this to the persistence
/// milestone: until v0.0.6 there was nowhere durable to keep it, so an
/// ephemeral per-launch id was used and the server's device list filled
/// with one entry per app start. From v0.0.6 the id is generated once and
/// persisted, so a server sees a single, stable Jellyfinity device.
abstract class DeviceIdentityStore {
  /// The persisted device id, generating and storing one on first call.
  Future<String> deviceId();
}

@LazySingleton(as: DeviceIdentityStore)
class PersistentDeviceIdentityStore implements DeviceIdentityStore {
  PersistentDeviceIdentityStore(this._store);

  final KeyValueStore _store;

  static const _key = 'device.id';

  @override
  Future<String> deviceId() async {
    final existing = await _store.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = const Uuid().v4();
    await _store.setString(_key, generated);
    return generated;
  }
}
