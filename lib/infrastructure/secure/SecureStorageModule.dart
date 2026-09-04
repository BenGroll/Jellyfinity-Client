import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// DI wiring for `flutter_secure_storage` (ADR-0009).
///
/// On Android the token is kept in `EncryptedSharedPreferences` (backed
/// by the Keystore) rather than the legacy plaintext-fallback store; on
/// iOS it lives in the Keychain, readable only after first unlock and not
/// synced to iCloud or migrated to a new device.
@module
abstract class SecureStorageModule {
  @lazySingleton
  FlutterSecureStorage secureStorage() => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
}
