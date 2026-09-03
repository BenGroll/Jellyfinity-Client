import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';

/// A validated, normalized Jellyfin base URL.
///
/// Users type server addresses loosely — `demo.jellyfin.org`,
/// `http://192.168.1.5:8096`, `https://media.example.com/jellyfin/`. This
/// turns that into one canonical form:
///
/// - a scheme is required; a bare host gets `https://` (the safe default,
///   overridable by typing `http://` explicitly);
/// - any trailing slash is removed, but a base path is kept
///   (`/jellyfin` reverse-proxy setups are common);
/// - query and fragment are dropped.
class JellyfinServerUrl {
  const JellyfinServerUrl._(this.uri);

  final Uri uri;

  /// The string to hand to an HTTP client as its base URL.
  String get baseUrl => uri.toString();

  static Result<JellyfinServerUrl> parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const Result.err(RecoverableFailure('Enter a server address.'));
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final parsed = Uri.tryParse(withScheme);
    if (parsed == null || parsed.host.isEmpty) {
      return const Result.err(
        RecoverableFailure("That doesn't look like a valid server address."),
      );
    }
    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      return const Result.err(
        RecoverableFailure(
          'A server address must start with http:// or https://.',
        ),
      );
    }

    var path = parsed.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    return Result.ok(
      JellyfinServerUrl._(
        Uri(
          scheme: parsed.scheme,
          host: parsed.host,
          port: parsed.hasPort ? parsed.port : null,
          path: path,
        ),
      ),
    );
  }
}
