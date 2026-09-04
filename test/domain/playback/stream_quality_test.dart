import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/playback/stream_quality.dart';

void main() {
  test('original has no target bitrate and is not transcoded', () {
    expect(StreamQuality.original.targetBitrateBps, isNull);
    expect(StreamQuality.original.isTranscoded, isFalse);
  });

  test('every non-original tier targets its documented bitrate', () {
    expect(StreamQuality.high.targetBitrateBps, 320000);
    expect(StreamQuality.medium.targetBitrateBps, 192000);
    expect(StreamQuality.dataSaver.targetBitrateBps, 128000);
    expect(StreamQuality.high.isTranscoded, isTrue);
    expect(StreamQuality.medium.isTranscoded, isTrue);
    expect(StreamQuality.dataSaver.isTranscoded, isTrue);
  });

  test('tryParse round-trips every member by name', () {
    for (final quality in StreamQuality.values) {
      expect(StreamQuality.tryParse(quality.name), quality);
    }
  });

  test('tryParse rejects unknown values', () {
    expect(StreamQuality.tryParse('ultra-hd'), isNull);
    expect(StreamQuality.tryParse(null), isNull);
  });

  test('fallback is original', () {
    expect(StreamQuality.fallback, StreamQuality.original);
  });
}
