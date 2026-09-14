import 'package:injectable/injectable.dart';

import '../../../core/logging/Logger.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/connected_playback/ConnectedPlaybackScope.dart';
import '../../../domain/connected_playback/RemoteQueueEntry.dart';
import '../../../domain/connected_playback/SyncPlayGroupMember.dart';
import '../../../domain/connected_playback/SyncPlayGroupUpdate.dart';
import '../../../domain/connected_playback/SyncPlayTransport.dart';
import '../../../domain/media/MediaId.dart';
import '../../../domain/playback/repeat_mode.dart';
import '../http/JellyfinHttpClient.dart';
import '../identity/auth_token_provider.dart';
import '../identity/JellyfinClientIdentity.dart';
import '../identity/JellyfinSessionContext.dart';
import 'JellyfinSessionApi.dart';
import 'JellyfinSessionTransport.dart';

const int _microsecondsPerTick = 10;

int _ticksOf(Duration duration) => duration.inMicroseconds * _microsecondsPerTick;

Duration _durationOfTicks(Object? ticks) {
  if (ticks is! int || ticks <= 0) return Duration.zero;
  return Duration(microseconds: ticks ~/ _microsecondsPerTick);
}

/// [SyncPlayTransport] over Jellyfin's own SyncPlay REST controller and
/// the `SyncPlayGroupUpdate` messages [JellyfinSessionTransport] already
/// receives on the one shared socket (v0.6.0, ADR-0045).
///
/// Every method here is REST, not the Jellyfinity envelope protocol — a
/// SyncPlay group is Jellyfin's own concept, and the server is the one
/// place that actually holds group membership and the shared queue.
/// [JellyfinSessionTransport] is only asked for the *scope* this device is
/// currently connected under and the raw update frames; it has no
/// SyncPlay-specific knowledge of its own.
///
/// Endpoint shapes here follow Jellyfin's documented SyncPlay controller
/// (`/SyncPlay/New`, `/Join`, `/Leave`, `/SetNewQueue`, and the transport
/// actions), but — unlike `JellyfinSessionApi`'s capability/session
/// endpoints, exercised against real servers over several prior
/// versions — this is this app's first SyncPlay code and has not yet been
/// verified against a live server. The v0.6.0 hardening pass's physical
/// acceptance step is where that verification belongs.
@LazySingleton(as: SyncPlayTransport)
class JellyfinSyncPlayApi implements SyncPlayTransport {
  JellyfinSyncPlayApi(
    this._context,
    this._transport,
    this._identity,
    this._authTokenProvider,
    this._logger,
  );

  final JellyfinSessionContext _context;
  final JellyfinSessionTransport _transport;
  final JellyfinClientIdentity _identity;
  final AuthTokenProvider _authTokenProvider;
  final Logger _logger;

  /// Overrides how the HTTP client is built. `null` in production.
  SessionHttpClientFactory? httpClientFactory;

  JellyfinHttpClient? _client;
  String? _clientBaseUrl;

  static const String _newGroupPath = '/SyncPlay/New';
  static const String _joinGroupPath = '/SyncPlay/Join';
  static const String _leaveGroupPath = '/SyncPlay/Leave';
  static const String _setQueuePath = '/SyncPlay/SetNewQueue';
  static const String _playPath = '/SyncPlay/Play';
  static const String _pausePath = '/SyncPlay/Pause';
  static const String _seekPath = '/SyncPlay/Seek';

  @override
  Stream<SyncPlayGroupUpdate> groupUpdates(ConnectedPlaybackScope scope) =>
      _transport
          .syncPlayFrames(scope)
          .map((raw) => _tryDecode(raw, scope.serverId))
          .where((update) => update != null)
          .cast<SyncPlayGroupUpdate>();

  @override
  Future<Result<void>> createGroup(ConnectedPlaybackScope scope) async {
    final client = _clientOrNull();
    if (client == null) return Result.err(_signedOut());
    return client.send(_newGroupPath, method: 'POST', body: const {});
  }

  @override
  Future<Result<void>> joinGroup(
    ConnectedPlaybackScope scope,
    String groupId,
  ) async {
    final client = _clientOrNull();
    if (client == null) return Result.err(_signedOut());
    return client.send(
      _joinGroupPath,
      method: 'POST',
      body: {'GroupId': groupId},
    );
  }

  @override
  Future<Result<void>> leaveGroup(ConnectedPlaybackScope scope) async {
    final client = _clientOrNull();
    if (client == null) return Result.err(_signedOut());
    return client.send(_leaveGroupPath, method: 'POST', body: const {});
  }

  @override
  Future<Result<void>> setQueue(
    ConnectedPlaybackScope scope, {
    required List<RemoteQueueEntry> entries,
    required int startIndex,
    required bool shuffleEnabled,
    required RepeatMode repeatMode,
    Duration startPosition = Duration.zero,
  }) async {
    final client = _clientOrNull();
    if (client == null) return Result.err(_signedOut());
    return client.send(
      _setQueuePath,
      method: 'POST',
      body: {
        'ItemIds': [for (final entry in entries) entry.id.itemId],
        'PlayingItemPosition': startIndex,
        'StartPositionTicks': _ticksOf(startPosition),
      },
    );
  }

  @override
  Future<Result<void>> play(ConnectedPlaybackScope scope) async {
    final client = _clientOrNull();
    if (client == null) return Result.err(_signedOut());
    return client.send(_playPath, method: 'POST', body: const {});
  }

  @override
  Future<Result<void>> pause(ConnectedPlaybackScope scope) async {
    final client = _clientOrNull();
    if (client == null) return Result.err(_signedOut());
    return client.send(_pausePath, method: 'POST', body: const {});
  }

  @override
  Future<Result<void>> seek(
    ConnectedPlaybackScope scope,
    Duration position,
  ) async {
    final client = _clientOrNull();
    if (client == null) return Result.err(_signedOut());
    return client.send(
      _seekPath,
      method: 'POST',
      body: {'PositionTicks': _ticksOf(position)},
    );
  }

  /// Decodes one raw `GroupUpdate` frame — Jellyfin's own envelope shape
  /// is `{GroupId, Type, Data}` regardless of which update `Type` names.
  /// An unreadable frame, or a `Type` this app does not model, decodes to
  /// [UnhandledSyncPlayUpdate] rather than being dropped silently.
  static SyncPlayGroupUpdate? _tryDecode(
    Map<String, Object?> raw,
    String serverId,
  ) {
    final type = raw['Type'];
    if (type is! String) return null;
    final groupId = raw['GroupId'] as String? ?? '';
    final data = raw['Data'];
    final payload = data is Map ? Map<String, Object?>.from(data) : const {};

    switch (type) {
      case 'GroupJoined':
        return SyncPlayGroupJoined(
          groupId: groupId,
          groupName: payload['GroupName'] as String? ?? 'Group',
          members: _membersOf(payload['Participants']),
          queue: _queueEntriesOf(payload['PlayQueue'], serverId),
          queuePosition: payload['PlayingItemPosition'] as int? ?? 0,
        );
      case 'GroupLeft':
        return const SyncPlayGroupLeft();
      case 'JoinGroupDenied':
      case 'GroupDoesNotExist':
      case 'CreateGroupDenied':
        return SyncPlayJoinDenied(
          payload['Reason'] as String? ??
              (type == 'GroupDoesNotExist'
                  ? 'That group no longer exists.'
                  : 'This server would not allow that.'),
        );
      case 'UserJoined':
        final name = payload['UserName'] as String? ?? 'A device';
        return SyncPlayUserJoined(
          SyncPlayGroupMember(
            sessionId: payload['SessionId'] as String? ?? name,
            displayName: name,
          ),
        );
      case 'UserLeft':
        return SyncPlayUserLeft(
          payload['SessionId'] as String? ??
              payload['UserName'] as String? ??
              '',
        );
      case 'PlayQueue':
        return SyncPlayQueueUpdated(
          entries: _queueEntriesOf(
            payload['Items'] ?? payload['PlayQueue'],
            serverId,
          ),
          startIndex: payload['PlayingItemPosition'] as int? ?? 0,
          shuffleEnabled: payload['ShuffleMode'] == 'Shuffle',
          repeatMode: _repeatModeOf(payload['RepeatMode']),
          startPosition: _durationOfTicks(payload['StartPositionTicks']),
          startPlaying: payload['IsPlaying'] as bool? ?? true,
        );
      case 'StateUpdate':
        return SyncPlayTransportUpdated(
          isPlaying: payload['IsPlaying'] as bool? ?? false,
          position: _durationOfTicks(payload['PositionTicks']),
        );
      default:
        return UnhandledSyncPlayUpdate(type);
    }
  }

  static List<SyncPlayGroupMember> _membersOf(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map)
          SyncPlayGroupMember(
            sessionId: entry['SessionId'] as String? ?? '',
            displayName: entry['UserName'] as String? ?? 'A device',
          ),
    ];
  }

  static List<RemoteQueueEntry> _queueEntriesOf(Object? raw, String serverId) {
    if (raw is! List) return const [];
    final entries = <RemoteQueueEntry>[];
    for (final entry in raw) {
      final itemId = entry is Map
          ? entry['ItemId'] as String?
          : entry is String
          ? entry
          : null;
      if (itemId == null || itemId.isEmpty) continue;
      entries.add(
        RemoteQueueEntry(
          id: MediaId(serverId: serverId, itemId: itemId),
          title: entry is Map ? entry['Name'] as String? ?? itemId : itemId,
        ),
      );
    }
    return entries;
  }

  static RepeatMode _repeatModeOf(Object? raw) => switch (raw) {
    'RepeatAll' => RepeatMode.all,
    'RepeatOne' => RepeatMode.one,
    _ => RepeatMode.off,
  };

  Failure _signedOut() =>
      const UnauthorizedFailure('Sign in to play on all your devices.');

  JellyfinHttpClient? _clientOrNull() {
    final baseUrl = _context.baseUrl;
    if (baseUrl == null) return null;
    final cached = _client;
    if (cached != null && _clientBaseUrl == baseUrl) return cached;
    _client?.close();
    final client = (httpClientFactory ?? _defaultClient)(baseUrl);
    _client = client;
    _clientBaseUrl = baseUrl;
    return client;
  }

  JellyfinHttpClient _defaultClient(String baseUrl) {
    _logger.debug('Opening a SyncPlay client for this server.');
    return JellyfinHttpClient(
      baseUrl: baseUrl,
      identity: _identity,
      authTokenProvider: _authTokenProvider,
      logger: _logger,
    );
  }
}
