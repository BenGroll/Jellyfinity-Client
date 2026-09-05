import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/playback/CrossfadeSettings.dart';

void main() {
  test('disabled is off at the default duration', () {
    expect(CrossfadeSettings.disabled.enabled, isFalse);
    expect(
      CrossfadeSettings.disabled.duration,
      CrossfadeSettings.defaultDuration,
    );
  });

  test('clampDuration keeps a value inside the supported range', () {
    expect(
      CrossfadeSettings.clampDuration(Duration.zero),
      CrossfadeSettings.minimumDuration,
    );
    expect(
      CrossfadeSettings.clampDuration(const Duration(minutes: 1)),
      CrossfadeSettings.maximumDuration,
    );
    expect(
      CrossfadeSettings.clampDuration(const Duration(seconds: 7)),
      const Duration(seconds: 7),
    );
  });

  test('copyWith clamps the duration it is given', () {
    final settings = CrossfadeSettings.disabled.copyWith(
      enabled: true,
      duration: const Duration(seconds: 99),
    );

    expect(settings.enabled, isTrue);
    expect(settings.duration, CrossfadeSettings.maximumDuration);
  });

  group('effectiveDurationFor', () {
    const settings = CrossfadeSettings(
      enabled: true,
      duration: Duration(seconds: 6),
    );

    test('is the configured duration for a track long enough to hold it', () {
      expect(
        settings.effectiveDurationFor(const Duration(minutes: 4)),
        const Duration(seconds: 6),
      );
    });

    test('shortens rather than skips the overlap on a short track', () {
      // A 6s overlap on an 8s track would still be fading the outgoing
      // source in when the next one starts.
      expect(
        settings.effectiveDurationFor(const Duration(seconds: 8)),
        const Duration(seconds: 4),
      );
    });

    test('is null when the source duration is unknown', () {
      expect(settings.effectiveDurationFor(null), isNull);
    });

    test('is null for a zero-length source', () {
      expect(settings.effectiveDurationFor(Duration.zero), isNull);
    });

    test('is null while crossfade is disabled', () {
      expect(
        CrossfadeSettings.disabled.effectiveDurationFor(
          const Duration(minutes: 4),
        ),
        isNull,
      );
    });
  });
}
