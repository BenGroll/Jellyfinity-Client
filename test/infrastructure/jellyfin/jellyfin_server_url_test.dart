import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/jellyfin_server_url.dart';

String _baseUrl(String input) {
  final result = JellyfinServerUrl.parse(input);
  return result.valueOrNull!.baseUrl;
}

void main() {
  group('JellyfinServerUrl.parse', () {
    test('adds https:// to a bare host', () {
      expect(_baseUrl('demo.jellyfin.org'), 'https://demo.jellyfin.org');
    });

    test('keeps an explicit http:// scheme', () {
      expect(_baseUrl('http://192.168.1.5:8096'), 'http://192.168.1.5:8096');
    });

    test('keeps a non-default port', () {
      expect(
        _baseUrl('https://media.example.com:8920'),
        'https://media.example.com:8920',
      );
    });

    test('strips a trailing slash but keeps a reverse-proxy base path', () {
      expect(
        _baseUrl('https://example.com/jellyfin/'),
        'https://example.com/jellyfin',
      );
    });

    test('drops query and fragment', () {
      expect(
        _baseUrl('https://example.com/jellyfin?x=1#y'),
        'https://example.com/jellyfin',
      );
    });

    test('trims surrounding whitespace', () {
      expect(_baseUrl('  https://example.com  '), 'https://example.com');
    });

    test('rejects an empty address with a recoverable failure', () {
      final result = JellyfinServerUrl.parse('   ');
      expect(result.failureOrNull, isA<RecoverableFailure>());
    });

    test('rejects an unsupported scheme', () {
      final result = JellyfinServerUrl.parse('ftp://example.com');
      expect(result.failureOrNull, isA<RecoverableFailure>());
    });

    test('rejects a string with no host', () {
      expect(
        JellyfinServerUrl.parse('https://').failureOrNull,
        isA<RecoverableFailure>(),
      );
    });
  });
}
