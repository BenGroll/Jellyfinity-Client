import 'package:injectable/injectable.dart';

import '../../domain/session/account_store.dart';
import '../../domain/session/jellyfin_account.dart';
import 'json_store.dart';

/// [AccountStore] backed by a single `accounts.json` document holding the
/// saved profiles and the active-account pointer.
///
/// Interim storage for v0.0.5 (see [JsonStore] and ADR-0009).
@LazySingleton(as: AccountStore)
class FileAccountStore implements AccountStore {
  FileAccountStore(this._store);

  static const _document = 'accounts';
  static const _accountsKey = 'accounts';
  static const _activeKey = 'activeAccountId';

  final JsonStore _store;

  List<JellyfinAccount>? _cache;
  String? _activeId;
  bool _loaded = false;

  Future<void> _load() async {
    if (_loaded) return;
    final doc = await _store.read(_document);
    final raw = doc[_accountsKey];
    _cache = <JellyfinAccount>[
      if (raw is List)
        for (final entry in raw)
          if (entry is Map<String, dynamic>) _fromJson(entry),
    ];
    final active = doc[_activeKey];
    _activeId = active is String ? active : null;
    _loaded = true;
  }

  Future<void> _persist() async {
    await _store.write(_document, {
      _accountsKey: [for (final a in _cache ?? const []) _toJson(a)],
      if (_activeId != null) _activeKey: _activeId,
    });
  }

  @override
  Future<List<JellyfinAccount>> all() async {
    await _load();
    return List.unmodifiable(_cache!);
  }

  @override
  Future<List<JellyfinAccount>> forServer(String serverId) async {
    await _load();
    return List.unmodifiable(_cache!.where((a) => a.serverId == serverId));
  }

  @override
  Future<JellyfinAccount?> byId(String id) async {
    await _load();
    for (final account in _cache!) {
      if (account.id == id) return account;
    }
    return null;
  }

  @override
  Future<JellyfinAccount?> byServerAndUser(
    String serverId,
    String userId,
  ) async {
    await _load();
    for (final account in _cache!) {
      if (account.serverId == serverId && account.userId == userId) {
        return account;
      }
    }
    return null;
  }

  @override
  Future<void> save(JellyfinAccount account) async {
    await _load();
    final index = _cache!.indexWhere((a) => a.id == account.id);
    if (index >= 0) {
      _cache![index] = account;
    } else {
      _cache!.add(account);
    }
    await _persist();
  }

  @override
  Future<void> remove(String id) async {
    await _load();
    _cache!.removeWhere((a) => a.id == id);
    if (_activeId == id) _activeId = null;
    await _persist();
  }

  @override
  Future<String?> activeAccountId() async {
    await _load();
    return _activeId;
  }

  @override
  Future<void> setActiveAccountId(String? id) async {
    await _load();
    if (id != null && !_cache!.any((a) => a.id == id)) {
      throw ArgumentError.value(id, 'id', 'not a saved account');
    }
    _activeId = id;
    await _persist();
  }

  static JellyfinAccount _fromJson(Map<String, dynamic> json) =>
      JellyfinAccount(
        id: json['id'] as String,
        serverId: json['serverId'] as String,
        userId: json['userId'] as String,
        username: json['username'] as String,
      );

  static Map<String, dynamic> _toJson(JellyfinAccount account) => {
    'id': account.id,
    'serverId': account.serverId,
    'userId': account.userId,
    'username': account.username,
  };
}
