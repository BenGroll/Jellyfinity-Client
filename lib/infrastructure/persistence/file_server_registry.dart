import 'package:injectable/injectable.dart';

import '../../domain/session/jellyfin_server.dart';
import '../../domain/session/server_registry.dart';
import 'json_store.dart';

/// [ServerRegistry] backed by a single `servers.json` document.
///
/// Interim storage for v0.0.5 (see [JsonStore] and ADR-0009). The list is
/// loaded once, cached in memory, and rewritten whole on every change —
/// fine for the handful of servers a user realistically saves.
@LazySingleton(as: ServerRegistry)
class FileServerRegistry implements ServerRegistry {
  FileServerRegistry(this._store);

  static const _document = 'servers';
  static const _key = 'servers';

  final JsonStore _store;

  List<JellyfinServer>? _cache;

  Future<List<JellyfinServer>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final doc = await _store.read(_document);
    final raw = doc[_key];
    final list = <JellyfinServer>[
      if (raw is List)
        for (final entry in raw)
          if (entry is Map<String, dynamic>) _fromJson(entry),
    ];
    return _cache = list;
  }

  Future<void> _persist() async {
    await _store.write(_document, {
      _key: [for (final server in _cache ?? const []) _toJson(server)],
    });
  }

  @override
  Future<List<JellyfinServer>> all() async => List.unmodifiable(await _load());

  @override
  Future<JellyfinServer?> byId(String id) async {
    for (final server in await _load()) {
      if (server.id == id) return server;
    }
    return null;
  }

  @override
  Future<JellyfinServer?> byBaseUrl(String baseUrl) async {
    for (final server in await _load()) {
      if (server.baseUrl == baseUrl) return server;
    }
    return null;
  }

  @override
  Future<void> save(JellyfinServer server) async {
    final list = await _load();
    final index = list.indexWhere((s) => s.id == server.id);
    if (index >= 0) {
      list[index] = server;
    } else {
      list.add(server);
    }
    await _persist();
  }

  @override
  Future<void> remove(String id) async {
    final list = await _load();
    list.removeWhere((s) => s.id == id);
    await _persist();
  }

  static JellyfinServer _fromJson(Map<String, dynamic> json) => JellyfinServer(
    id: json['id'] as String,
    baseUrl: json['baseUrl'] as String,
    name: json['name'] as String,
    reportedVersion: json['reportedVersion'] as String? ?? '',
    serverId: json['serverId'] as String?,
  );

  static Map<String, dynamic> _toJson(JellyfinServer server) => {
    'id': server.id,
    'baseUrl': server.baseUrl,
    'name': server.name,
    'reportedVersion': server.reportedVersion,
    if (server.serverId != null) 'serverId': server.serverId,
  };
}
