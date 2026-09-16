import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackLimits.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceAdvertisement.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceCapabilities.dart';
import 'package:jellyfinity/domain/connected_playback/remote_command_kind.dart';

void main() {
  test('round-trips everything a peer needs to know', () {
    final advertisement = DeviceAdvertisement(
      deviceId: 'device-tv',
      name: 'Living Room',
      platform: 'Fire TV',
      isPlaying: true,
      nowPlayingTitle: 'So What',
      nowPlayingArtist: 'Miles Davis',
      capabilities: DeviceCapabilities.fullPlayer(),
    );

    final decoded = DeviceAdvertisement.tryDecode(advertisement.toPayload());

    expect(decoded, advertisement);
  });

  test('keeps a newer peer\'s capabilities it has never heard of', () {
    final decoded = DeviceAdvertisement.tryDecode({
      'deviceId': 'device-tv',
      'name': 'Living Room',
      'canPlay': true,
      'canControl': true,
      'commands': ['play', 'pause', 'castToTheMoon'],
    });

    expect(decoded!.capabilities.acceptedCommands, {
      RemoteCommandKind.play,
      RemoteCommandKind.pause,
    });
    expect(decoded.capabilities.unknownCapabilities, ['castToTheMoon']);
  });

  test(
    'a peer that claims a bigger queue than agreed is held to the bound',
    () {
      final decoded = DeviceAdvertisement.tryDecode({
        'deviceId': 'device-tv',
        'name': 'Living Room',
        'maxQueueEntries': 1000000,
      });

      expect(
        decoded!.capabilities.maxQueueEntries,
        ConnectedPlaybackLimits.maxQueueEntries,
      );
    },
  );

  test('a peer that asks for less than agreed gets it', () {
    final decoded = DeviceAdvertisement.tryDecode({
      'deviceId': 'device-tv',
      'name': 'Living Room',
      'maxQueueEntries': 50,
    });

    expect(decoded!.capabilities.maxQueueEntries, 50);
  });

  test(
    'a badly formed advertisement reads as a device that accepts nothing',
    () {
      final decoded = DeviceAdvertisement.tryDecode({
        'deviceId': 'device-tv',
        'name': 'Living Room',
        'commands': 'not a list',
      });

      expect(decoded!.capabilities.canPlay, isFalse);
      expect(decoded.capabilities.canReceiveTransfer, isFalse);
    },
  );

  test('without an identity there is no device to describe', () {
    expect(DeviceAdvertisement.tryDecode({'name': 'Living Room'}), isNull);
    expect(DeviceAdvertisement.tryDecode({'deviceId': 'device-tv'}), isNull);
  });
}
