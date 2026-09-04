import 'package:equatable/equatable.dart';

import 'ServerVersion.dart';

/// A Jellyfin server that has been reached, identified, and confirmed to
/// meet Jellyfinity's version policy.
///
/// This is the successful output of `JellyfinServerProbe.validate`. It is
/// deliberately small — just what v0.0.4 can establish without a login.
/// v0.0.5 builds the saved-server / active-session concepts on top of it;
/// they are not this type's job.
class JellyfinServerInfo extends Equatable {
  const JellyfinServerInfo({
    required this.baseUrl,
    required this.version,
    this.serverName,
    this.serverId,
  });

  /// The normalized base URL the server answered on.
  final String baseUrl;

  /// The server's reported version, already checked against the policy.
  final ServerVersion version;

  /// The server's self-assigned display name, if it provided one.
  final String? serverName;

  /// The server's stable id, if it provided one.
  final String? serverId;

  @override
  List<Object?> get props => [baseUrl, version, serverName, serverId];
}
