import 'package:jellyfinity/domain/connected_playback/ConnectedDevice.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackScope.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceCapabilities.dart';
import 'package:jellyfinity/domain/connected_playback/ProtocolVersion.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteQueueEntry.dart';
import 'package:jellyfinity/domain/connected_playback/device_reachability.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';

/// The profile every test shares unless it is testing isolation.
const ConnectedPlaybackScope testScope = ConnectedPlaybackScope(
  serverId: 'server-1',
  userId: 'user-1',
);

/// A second profile, for the isolation tests. Same server on purpose:
/// two profiles on one server is the case where a permissive Jellyfin
/// would happily let the wrong state through.
const ConnectedPlaybackScope otherProfileScope = ConnectedPlaybackScope(
  serverId: 'server-1',
  userId: 'user-2',
);

/// A different server, same user id — the other way isolation can fail.
const ConnectedPlaybackScope otherServerScope = ConnectedPlaybackScope(
  serverId: 'server-2',
  userId: 'user-1',
);

RemoteQueueEntry entry(
  String id, {
  String? title,
  ConnectedPlaybackScope scope = testScope,
}) => RemoteQueueEntry(
  id: MediaId(serverId: scope.serverId, itemId: id),
  title: title ?? 'Track $id',
  artist: 'Artist $id',
  duration: const Duration(minutes: 3),
);

List<RemoteQueueEntry> entries(
  int count, {
  ConnectedPlaybackScope scope = testScope,
}) => [for (var i = 0; i < count; i++) entry('t$i', scope: scope)];

ConnectedDevice device({
  String deviceId = 'device-tv',
  String sessionId = 'session-tv',
  String name = 'Living Room',
  String? nameHint,
  ConnectedPlaybackScope scope = testScope,
  DeviceCapabilities? capabilities,
  DeviceReachability reachability = DeviceReachability.ready,
  ProtocolVersion? protocolVersion,
  bool isThisDevice = false,
  bool isPlaying = false,
}) => ConnectedDevice(
  scope: scope,
  deviceId: deviceId,
  sessionId: sessionId,
  name: name,
  nameHint: nameHint,
  protocolVersion: protocolVersion ?? ProtocolVersion.current,
  capabilities: capabilities ?? DeviceCapabilities.fullPlayer(),
  reachability: reachability,
  lastSeen: Duration.zero,
  isThisDevice: isThisDevice,
  isPlaying: isPlaying,
);
