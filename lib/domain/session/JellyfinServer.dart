import 'package:equatable/equatable.dart';

/// A Jellyfin server Jellyfinity has connected to and saved.
///
/// This is one of the five session concepts `CONTEXT.md` insists stay
/// distinct (server / user / credential / saved profile / active profile).
/// A [JellyfinServer] is *just the machine*: where it is and what it calls
/// itself. It carries no user and no token — those are [JellyfinAccount]
/// and the credential store.
///
/// [id] is Jellyfinity's own local identifier (so two saved entries for
/// the same address, or a server that later changes its reported id, stay
/// separable). [serverId] is the server's self-reported Jellyfin id, kept
/// for display and future duplicate detection only.
class JellyfinServer extends Equatable {
  const JellyfinServer({
    required this.id,
    required this.baseUrl,
    required this.name,
    required this.reportedVersion,
    this.serverId,
  });

  /// Jellyfinity's local id for this saved server (a UUID).
  final String id;

  /// The normalized base URL, as produced by `JellyfinServerUrl`.
  final String baseUrl;

  /// A display name — the server's own name if it reported one, otherwise
  /// something derived from the host.
  final String name;

  /// The Jellyfin version string seen at connection time (e.g. `10.11.6`).
  /// Informational; the version *policy* check happens in the probe.
  final String reportedVersion;

  /// The server's self-assigned Jellyfin id, if it provided one.
  final String? serverId;

  JellyfinServer copyWith({
    String? baseUrl,
    String? name,
    String? reportedVersion,
    String? serverId,
  }) {
    return JellyfinServer(
      id: id,
      baseUrl: baseUrl ?? this.baseUrl,
      name: name ?? this.name,
      reportedVersion: reportedVersion ?? this.reportedVersion,
      serverId: serverId ?? this.serverId,
    );
  }

  @override
  List<Object?> get props => [id, baseUrl, name, reportedVersion, serverId];
}
