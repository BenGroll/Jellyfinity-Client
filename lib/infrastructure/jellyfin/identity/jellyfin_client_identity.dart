import 'dart:math';

/// The version string Jellyfinity reports to Jellyfin servers as its
/// client version.
///
/// Kept in sync with `pubspec.yaml` by hand for now. Once release
/// packaging matters (see `OUTLOOK.md` §23) this should come from
/// `package_info_plus` instead of a constant.
const String kJellyfinityClientVersion = '0.0.4';

/// The product name Jellyfinity identifies itself as. Jellyfin shows this
/// in its "Devices" / active-sessions views.
const String kJellyfinityClientName = 'Jellyfinity';

/// Everything Jellyfinity has to tell a Jellyfin server about itself on
/// every request: which app, which version, and which device.
///
/// Jellyfin carries all of this — plus the session token once the user has
/// logged in — in a single `Authorization` header, so identity and auth
/// are one concern at the transport level, not two.
///
/// Construction is centralized: resolve the DI-registered singleton rather
/// than building one ad hoc, so every request reports the same device.
class JellyfinClientIdentity {
  const JellyfinClientIdentity({
    required this.clientName,
    required this.clientVersion,
    required this.deviceName,
    required this.deviceId,
  });

  /// Builds the identity for this application, with [kJellyfinityClientName]
  /// and [kJellyfinityClientVersion] filled in.
  ///
  /// [deviceId] should be stable for the lifetime of an install. Until the
  /// persistence layer (v0.0.6) exists, callers pass an ephemeral id via
  /// [ephemeralDeviceId]; a server will then see a new device per launch,
  /// which is acceptable while there is no login.
  factory JellyfinClientIdentity.forThisApp({
    required String deviceId,
    String deviceName = 'Jellyfinity',
  }) {
    return JellyfinClientIdentity(
      clientName: kJellyfinityClientName,
      clientVersion: kJellyfinityClientVersion,
      deviceName: deviceName,
      deviceId: deviceId,
    );
  }

  /// The name of the app (shown in Jellyfin's session list).
  final String clientName;

  /// The app version (e.g. `0.0.4`).
  final String clientVersion;

  /// A human-readable device label (e.g. `Jellyfinity`, later the actual
  /// device model).
  final String deviceName;

  /// A stable, opaque identifier for this device/install.
  final String deviceId;

  /// The HTTP header name identity/auth is sent under.
  static const String authorizationHeader = 'Authorization';

  /// The value for [authorizationHeader] on a request.
  ///
  /// [token] is the authenticated session token; omit it (or pass `null`)
  /// before the user has logged in — the request is then identified but
  /// unauthenticated, which is all v0.0.4 needs.
  String authorizationHeaderValue({String? token}) {
    final fields = <String, String>{
      'Client': clientName,
      'Version': clientVersion,
      'DeviceId': deviceId,
      'Device': deviceName,
      if (token != null && token.isNotEmpty) 'Token': token,
    };
    final encoded = fields.entries
        .map((entry) => '${entry.key}="${_escape(entry.value)}"')
        .join(', ');
    return 'MediaBrowser $encoded';
  }

  static String _escape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}

/// Generates a random 32-character hex id, used as an ephemeral device id
/// until v0.0.6 persists a stable one.
String generateEphemeralDeviceId() {
  final random = Random();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
