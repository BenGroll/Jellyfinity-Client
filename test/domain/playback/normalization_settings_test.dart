import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/playback/NormalizationSettings.dart';

void main() {
  test('disabled is off', () {
    expect(NormalizationSettings.disabled.enabled, isFalse);
  });

  group('volumeFactorFor', () {
    const enabled = NormalizationSettings(enabled: true);

    test('is unity while disabled, regardless of the reported gain', () {
      expect(NormalizationSettings.disabled.volumeFactorFor(-6), 1);
      expect(NormalizationSettings.disabled.volumeFactorFor(6), 1);
    });

    test('is unity for a track with no reported gain', () {
      expect(enabled.volumeFactorFor(null), 1);
    });

    test('attenuates a track reported louder than the reference', () {
      // -6 dB is roughly a quarter of the amplitude.
      expect(enabled.volumeFactorFor(-6), closeTo(0.501, 0.001));
    });

    test('never boosts above unity for a track quieter than the reference', () {
      // A positive NormalizationGain means "turn this up to reach the
      // reference" — clamped here rather than applied, since boosting
      // without a limiter risks clipping.
      expect(enabled.volumeFactorFor(6), 1);
    });

    test('is unity for exactly the reference loudness', () {
      expect(enabled.volumeFactorFor(0), 1);
    });
  });
}
