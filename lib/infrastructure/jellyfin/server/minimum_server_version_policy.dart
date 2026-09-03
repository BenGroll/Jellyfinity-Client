import 'server_version.dart';

/// Decides whether a Jellyfin server is new enough for Jellyfinity.
///
/// `CONTEXT.md` sets the initial floor at Jellyfin **10.11.6**. The policy
/// is a single value so raising (or, per `OUTLOOK.md` §21, deliberately
/// lowering with a compatibility matrix) the floor later is a one-line
/// change here, not a hunt through the transport code.
class MinimumServerVersionPolicy {
  const MinimumServerVersionPolicy(this.minimum);

  /// The floor Jellyfinity currently ships with.
  static const MinimumServerVersionPolicy current = MinimumServerVersionPolicy(
    ServerVersion(10, 11, 6),
  );

  final ServerVersion minimum;

  bool isSupported(ServerVersion version) => version >= minimum;
}
