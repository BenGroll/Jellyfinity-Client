import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/playback_progress.dart';

void main() {
  test('nothing played is not started and not resumable', () {
    expect(PlaybackProgress.none.isStarted, isFalse);
    expect(PlaybackProgress.none.isResumable, isFalse);
    expect(PlaybackProgress.none.completed, isFalse);
  });

  test('a part-played item is resumable', () {
    const progress = PlaybackProgress(position: Duration(minutes: 12));

    expect(progress.isStarted, isTrue);
    expect(progress.isResumable, isTrue);
  });

  test('a finished item is not offered as resumable', () {
    const progress = PlaybackProgress(
      position: Duration(minutes: 95),
      completed: true,
    );

    expect(progress.isStarted, isTrue);
    expect(progress.isResumable, isFalse);
  });

  test('reports its position as a fraction of the running time', () {
    const progress = PlaybackProgress(position: Duration(minutes: 30));

    expect(progress.fractionOf(const Duration(minutes: 120)), 0.25);
  });

  test('an unknown or zero running time yields no fraction, not a crash', () {
    const progress = PlaybackProgress(position: Duration(minutes: 30));

    expect(progress.fractionOf(Duration.zero), 0);
  });

  test('clamps a position past the end', () {
    const progress = PlaybackProgress(position: Duration(minutes: 130));

    expect(progress.fractionOf(const Duration(minutes: 120)), 1);
  });
}
