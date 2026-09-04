import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media_availability.dart';

void main() {
  test('only remotely-unavailable media is unplayable', () {
    for (final availability in MediaAvailability.values) {
      expect(
        availability.isPlayable,
        availability != MediaAvailability.remoteUnavailable,
        reason: 'for $availability',
      );
    }
  });

  test('downloaded media does not need the server', () {
    expect(MediaAvailability.localOnly.isOnDevice, isTrue);
    expect(MediaAvailability.localAndRemote.isOnDevice, isTrue);

    expect(MediaAvailability.remoteOnly.isOnDevice, isFalse);
    expect(MediaAvailability.remoteUnavailable.isOnDevice, isFalse);
  });

  test('a partially available collection is still playable', () {
    // The twelve-track album with one dead track stays an album.
    expect(MediaAvailability.partiallyAvailable.isPlayable, isTrue);
  });
}
