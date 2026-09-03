import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../../domain/session/credential_store.dart';

/// [CredentialStore] backed by `flutter_secure_storage` — the iOS
/// Keychain and Android Keystore-wrapped `EncryptedSharedPreferences`
/// (ADR-0009).
///
/// Tokens are stored under a namespaced key per account so they never
/// collide with anything else the app might keep in secure storage later.
@LazySingleton(as: CredentialStore)
class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _keyPrefix = 'jellyfin_token_';

  String _keyFor(String accountId) => '$_keyPrefix$accountId';

  @override
  Future<String?> readToken(String accountId) =>
      _storage.read(key: _keyFor(accountId));

  @override
  Future<void> writeToken(String accountId, String token) =>
      _storage.write(key: _keyFor(accountId), value: token);

  @override
  Future<void> deleteToken(String accountId) =>
      _storage.delete(key: _keyFor(accountId));
}
