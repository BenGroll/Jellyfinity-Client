import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../core/logging/Logger.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../http/JellyfinHttpClient.dart';
import '../identity/auth_token_provider.dart';
import '../identity/JellyfinClientIdentity.dart';
import 'JellyfinServerInfo.dart';
import 'JellyfinServerUrl.dart';
import 'MinimumServerVersionPolicy.dart';
import 'PublicSystemInfoDto.dart';
import 'ServerVersion.dart';

/// Builds a [JellyfinHttpClient] for a given base URL. Injected into
/// [JellyfinServerProbe] so tests can supply a client wired to a fake
/// `dio` adapter.
typedef JellyfinHttpClientFactory = JellyfinHttpClient Function(String baseUrl);

/// Checks that an address is a Jellyfin server Jellyfinity can use:
/// reachable, actually Jellyfin, and running a supported version.
///
/// This is the concrete deliverable of v0.0.4's "validate a Jellyfin
/// server / enforce the supported server-version policy". It returns a
/// [JellyfinServerInfo] on success and a normalized [Failure] otherwise —
/// v0.0.5's "add a server" flow calls straight into this.
@lazySingleton
class JellyfinServerProbe {
  JellyfinServerProbe(this._identity, this._authTokenProvider, this._logger);

  final JellyfinClientIdentity _identity;
  final AuthTokenProvider _authTokenProvider;
  final Logger _logger;

  /// The version floor this probe enforces. Defaults to the shipped
  /// policy; a test (or a future settings surface) can lower it.
  MinimumServerVersionPolicy versionPolicy = MinimumServerVersionPolicy.current;

  /// Overrides how the probe builds its HTTP client. `null` in production
  /// (the probe builds a real one); a test assigns a factory wired to a
  /// fake `dio` adapter so `validate` runs without a network.
  JellyfinHttpClientFactory? httpClientFactory;

  /// Jellyfin's unauthenticated server-identification endpoint.
  static const String publicSystemInfoPath = '/System/Info/Public';

  Future<Result<JellyfinServerInfo>> validate(
    String rawUrl, {
    CancelToken? cancelToken,
  }) async {
    final urlResult = JellyfinServerUrl.parse(rawUrl);
    if (urlResult case Err<JellyfinServerUrl>(:final failure)) {
      return Result.err(failure);
    }
    final url = (urlResult as Ok<JellyfinServerUrl>).value;

    final client = (httpClientFactory ?? _defaultHttpClient)(url.baseUrl);
    try {
      final infoResult = await client.getJson<PublicSystemInfoDto>(
        publicSystemInfoPath,
        parse: PublicSystemInfoDto.fromJson,
        cancelToken: cancelToken,
      );
      if (infoResult case Err<PublicSystemInfoDto>(:final failure)) {
        return Result.err(failure);
      }
      final info = (infoResult as Ok<PublicSystemInfoDto>).value;

      if (!_looksLikeJellyfin(info)) {
        return const Result.err(
          UnsupportedServerFailure(
            'That address answered, but it does not look like a Jellyfin '
            'server.',
          ),
        );
      }

      final version = ServerVersion.tryParse(info.version ?? '');
      if (version == null) {
        return const Result.err(
          UnsupportedServerFailure(
            "Jellyfinity could not read the server's version.",
          ),
        );
      }
      if (!versionPolicy.isSupported(version)) {
        return Result.err(
          UnsupportedServerFailure(
            'This server runs Jellyfin $version. Jellyfinity needs '
            '${versionPolicy.minimum} or newer.',
          ),
        );
      }

      return Result.ok(
        JellyfinServerInfo(
          baseUrl: url.baseUrl,
          version: version,
          serverName: info.serverName,
          serverId: info.id,
        ),
      );
    } finally {
      client.close();
    }
  }

  bool _looksLikeJellyfin(PublicSystemInfoDto info) {
    final product = info.productName?.toLowerCase();
    return product != null && product.contains('jellyfin');
  }

  JellyfinHttpClient _defaultHttpClient(String baseUrl) => JellyfinHttpClient(
    baseUrl: baseUrl,
    identity: _identity,
    authTokenProvider: _authTokenProvider,
    logger: _logger,
  );
}
