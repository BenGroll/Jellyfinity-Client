import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackLimits.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceAdvertisement.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceCapabilities.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceObservation.dart';
import 'package:jellyfinity/domain/connected_playback/DevicePresenceRegistry.dart';
import 'package:jellyfinity/domain/connected_playback/ProtocolVersion.dart';
import 'package:jellyfinity/domain/connected_playback/connection_state.dart';
import 'package:jellyfinity/domain/connected_playback/device_reachability.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/media/MediaImage.dart';

import '../../support/connected_playback/FakeElapsedClock.dart';
import '../../support/connected_playback/connected_playback_fixtures.dart';

void main() {
  late FakeElapsedClock clock;
  late DevicePresenceRegistry registry;

  setUp(() {
    clock = FakeElapsedClock();
    registry = DevicePresenceRegistry(scope: testScope, clock: clock)
      ..setLink(ConnectedPlaybackConnection.connected);
  });

  DeviceObservation seen(
    String deviceId, {
    String? sessionId,
    String name = 'Living Room',
    bool supportsRemoteControl = true,
    bool isPlaying = false,
    bool isThisDevice = false,
  }) => DeviceObservation(
    deviceId: deviceId,
    sessionId: sessionId ?? 'session-$deviceId',
    name: name,
    supportsRemoteControl: supportsRemoteControl,
    isPlaying: isPlaying,
    isThisDevice: isThisDevice,
  );

  DeviceAdvertisement advertises(
    String deviceId, {
    String name = 'Living Room',
    String? platform,
    bool canPlay = true,
    bool canControl = true,
    bool isPlaying = false,
  }) => DeviceAdvertisement(
    deviceId: deviceId,
    name: name,
    platform: platform,
    isPlaying: isPlaying,
    capabilities: DeviceCapabilities.fullPlayer().copyWith(
      canPlay: canPlay,
      canControl: canControl,
    ),
  );

  group('discovery', () {
    test('lists every session the server reported', () {
      registry.replaceAll([
        seen('tv', name: 'Living Room'),
        seen('phone', name: 'Phone'),
        seen('desktop', name: 'Desktop', isThisDevice: true),
      ]);

      expect(registry.devices.map((device) => device.name), [
        'Desktop',
        'Living Room',
        'Phone',
      ]);
      expect(
        registry.devices
            .singleWhere((d) => d.deviceId == 'desktop')
            .isThisDevice,
        isTrue,
      );
    });

    test('a device the server knows but that has not introduced itself is '
        'present, not ready', () {
      registry.replaceAll([seen('tv')]);

      final tv = registry.devices.single;
      expect(tv.reachability, DeviceReachability.presenceOnly);
      expect(tv.capabilities, DeviceCapabilities.none);
      expect(tv.canReceiveTransfer, isFalse);
    });

    test('becomes ready once the peer advertises what it accepts', () {
      registry.replaceAll([seen('tv')]);

      final changed = registry.applyAdvertisement(
        'session-tv',
        ProtocolVersion.current,
        advertises('tv'),
      );

      expect(changed, isTrue);
      final tv = registry.devices.single;
      expect(tv.reachability, DeviceReachability.ready);
      expect(tv.canReceiveTransfer, isTrue);
      expect(tv.canBeControlled, isTrue);
    });

    test(
      'rebinds a peer\'s now-playing artwork to this install\'s local server id',
      () {
        registry.replaceAll([seen('tv')]);

        registry.applyAdvertisement(
          'session-tv',
          ProtocolVersion.current,
          DeviceAdvertisement(
            deviceId: 'tv',
            name: 'Living Room',
            isPlaying: true,
            nowPlayingImage: MediaImage(
              itemId: MediaId(
                serverId: 'senders-own-local-id',
                itemId: 'track-1',
              ),
              kind: MediaImageKind.primary,
              tag: 'tag-1',
            ),
            capabilities: DeviceCapabilities.fullPlayer(),
          ),
        );

        final image = registry.devices.single.nowPlayingImage;
        expect(image, isNotNull);
        expect(
          image!.itemId,
          MediaId(serverId: testScope.serverId, itemId: 'track-1'),
        );
      },
    );

    test(
      'an advertisement from a session the server never listed is ignored',
      () {
        expect(
          registry.applyAdvertisement(
            'session-ghost',
            ProtocolVersion.current,
            advertises('ghost'),
          ),
          isFalse,
        );
        expect(registry.devices, isEmpty);
      },
    );

    test(
      'a session that will not accept commands is listed but not offered',
      () {
        registry
          ..replaceAll([seen('tv', supportsRemoteControl: false)])
          ..applyAdvertisement(
            'session-tv',
            ProtocolVersion.current,
            advertises('tv'),
          );

        final tv = registry.devices.single;
        expect(tv.reachability, DeviceReachability.presenceOnly);
        expect(tv.canReceiveTransfer, isFalse);
      },
    );

    test('a session missing from one read ages out rather than vanishing', () {
      registry.replaceAll([seen('tv'), seen('phone', name: 'Phone')]);

      registry.replaceAll([seen('tv')]);

      // Still there: one poll that omitted it is not proof it left, and a
      // row that disappears under a listener's finger is worse than one
      // that lingers a moment.
      expect(registry.devices.map((device) => device.deviceId), [
        'tv',
        'phone',
      ]);

      clock.advance(ConnectedPlaybackLimits.presenceStaleAfter * 2);
      registry.replaceAll([seen('tv')]);

      final phone = registry.devices.singleWhere((d) => d.deviceId == 'phone');
      expect(phone.reachability, DeviceReachability.stale);
      expect(phone.canBeControlled, isFalse);
    });

    test('re-reading an unchanged roster reports no change', () {
      registry.replaceAll([seen('tv'), seen('phone', name: 'Phone')]);
      clock.advance(const Duration(seconds: 5));

      expect(
        registry.replaceAll([seen('tv'), seen('phone', name: 'Phone')]),
        isFalse,
      );
    });
  });

  group('duplicate names', () {
    test('distinguishes them by platform when that separates them', () {
      registry.replaceAll([seen('tv'), seen('desktop')]);
      registry
        ..applyAdvertisement(
          'session-tv',
          ProtocolVersion.current,
          advertises('tv', platform: 'Fire TV'),
        )
        ..applyAdvertisement(
          'session-desktop',
          ProtocolVersion.current,
          advertises('desktop', platform: 'Windows'),
        );

      expect(registry.devices.map((device) => device.displayName), [
        'Living Room (Fire TV)',
        'Living Room (Windows)',
      ]);
    });

    test('falls back to the stable install id when the platform does not', () {
      registry.replaceAll([seen('device-aaaa'), seen('device-bbbb')]);
      registry
        ..applyAdvertisement(
          'session-device-aaaa',
          ProtocolVersion.current,
          advertises('device-aaaa', platform: 'Windows'),
        )
        ..applyAdvertisement(
          'session-device-bbbb',
          ProtocolVersion.current,
          advertises('device-bbbb', platform: 'Windows'),
        );

      expect(registry.devices.map((device) => device.displayName), [
        'Living Room (AAAA)',
        'Living Room (BBBB)',
      ]);
    });

    test('the hint survives an unrelated device joining or leaving', () {
      registry.replaceAll([seen('device-aaaa'), seen('device-bbbb')]);
      final before = registry.devices
          .singleWhere((device) => device.deviceId == 'device-aaaa')
          .displayName;

      registry.replaceAll([
        seen('device-aaaa'),
        seen('device-bbbb'),
        seen('phone', name: 'Phone'),
      ]);

      expect(
        registry.devices
            .singleWhere((device) => device.deviceId == 'device-aaaa')
            .displayName,
        before,
      );
    });

    test('a unique name is never given a hint', () {
      registry.replaceAll([seen('tv'), seen('phone', name: 'Phone')]);

      expect(registry.devices.map((device) => device.nameHint), [null, null]);
    });

    test('a peer that renames itself is listed under its own name', () {
      registry
        ..replaceAll([seen('tv', name: 'Old name')])
        ..applyAdvertisement(
          'session-tv',
          ProtocolVersion.current,
          advertises('tv', name: 'Kitchen speaker'),
        );

      expect(registry.devices.single.name, 'Kitchen speaker');
    });
  });

  group('expiry', () {
    test('a device that goes quiet becomes stale and stops being offered', () {
      registry
        ..replaceAll([seen('tv')])
        ..applyAdvertisement(
          'session-tv',
          ProtocolVersion.current,
          advertises('tv'),
        );
      expect(registry.devices.single.reachability, DeviceReachability.ready);

      clock.advance(
        ConnectedPlaybackLimits.presenceStaleAfter + const Duration(seconds: 1),
      );

      final tv = registry.devices.single;
      expect(tv.reachability, DeviceReachability.stale);
      expect(tv.canReceiveTransfer, isFalse);
      expect(tv.reachability.isListable, isFalse);
    });

    test('pruning only drops devices past the longer drop window', () {
      registry.replaceAll([seen('tv')]);

      clock.advance(
        ConnectedPlaybackLimits.presenceStaleAfter + const Duration(seconds: 1),
      );
      expect(registry.prune(), isFalse);
      expect(registry.devices, hasLength(1));

      clock.advance(ConnectedPlaybackLimits.presenceDropAfter);
      expect(registry.prune(), isTrue);
      expect(registry.devices, isEmpty);
    });

    test(
      'being heard from again is not a change a picker should redraw for',
      () {
        registry.replaceAll([seen('tv')]);
        clock.advance(const Duration(seconds: 30));

        expect(registry.observe(seen('tv')), isFalse);
      },
    );
  });

  group('reconnection', () {
    test('the same install under a new session id stays one row', () {
      registry
        ..replaceAll([seen('tv', sessionId: 'session-1')])
        ..applyAdvertisement(
          'session-1',
          ProtocolVersion.current,
          advertises('tv'),
        );

      registry.replaceAll([seen('tv', sessionId: 'session-2')]);

      expect(registry.devices, hasLength(1));
      expect(registry.devices.single.sessionId, 'session-2');
    });

    test(
      'a reconnected peer is not treated as ready until it advertises again',
      () {
        registry
          ..replaceAll([seen('tv', sessionId: 'session-1')])
          ..applyAdvertisement(
            'session-1',
            ProtocolVersion.current,
            advertises('tv'),
          )
          ..replaceAll([seen('tv', sessionId: 'session-2')]);

        expect(
          registry.devices.single.reachability,
          DeviceReachability.presenceOnly,
        );

        registry.applyAdvertisement(
          'session-2',
          ProtocolVersion.current,
          advertises('tv'),
        );
        expect(registry.devices.single.reachability, DeviceReachability.ready);
      },
    );

    test('an advertisement addressed to the previous session is ignored', () {
      registry
        ..replaceAll([seen('tv', sessionId: 'session-1')])
        ..replaceAll([seen('tv', sessionId: 'session-2')]);

      expect(
        registry.applyAdvertisement(
          'session-1',
          ProtocolVersion.current,
          advertises('tv'),
        ),
        isFalse,
      );
    });

    test('a brief stutter does not take every peer away', () {
      registry
        ..replaceAll([seen('tv')])
        ..applyAdvertisement(
          'session-tv',
          ProtocolVersion.current,
          advertises('tv'),
        )
        ..setLink(ConnectedPlaybackConnection.reconnecting);

      // A socket that drops and comes back is the ordinary condition of a
      // phone on wifi. Emptying the device list for it is what made this
      // feature feel broken on a good connection.
      expect(registry.devices.single.reachability, DeviceReachability.ready);
    });

    test('a reconnect that does not come back stops offering its peers', () {
      registry
        ..replaceAll([seen('tv')])
        ..applyAdvertisement(
          'session-tv',
          ProtocolVersion.current,
          advertises('tv'),
        )
        ..setLink(ConnectedPlaybackConnection.reconnecting);

      clock.advance(ConnectedPlaybackLimits.linkDegradedGrace * 2);

      expect(
        registry.devices.single.reachability,
        DeviceReachability.presenceOnly,
      );
    });

    test('an unreachable server reads as offline, not as devices gone', () {
      registry
        ..replaceAll([seen('tv')])
        ..setLink(ConnectedPlaybackConnection.offline);

      // Past the grace a failed poll stops being a stutter and starts
      // being an outage; the row stays, and says so.
      clock.advance(ConnectedPlaybackLimits.linkDegradedGrace * 2);

      expect(registry.devices.single.reachability, DeviceReachability.offline);
    });
  });

  group('refusals', () {
    test('an incompatible peer is listed, explained, and never offered', () {
      registry
        ..replaceAll([seen('tv')])
        ..markIncompatible('session-tv', const ProtocolVersion(2, 0));

      final tv = registry.devices.single;
      expect(tv.reachability, DeviceReachability.incompatible);
      expect(tv.protocolVersion, const ProtocolVersion(2, 0));
      expect(tv.canReceiveTransfer, isFalse);
      expect(tv.reachability.isListable, isTrue);
    });

    test('a peer this profile may not control says so', () {
      registry
        ..replaceAll([seen('tv')])
        ..applyAdvertisement(
          'session-tv',
          ProtocolVersion.current,
          advertises('tv'),
        )
        ..markNotPermitted('session-tv');

      expect(
        registry.devices.single.reachability,
        DeviceReachability.notPermitted,
      );
    });
  });

  group('isolation', () {
    test('clearing forgets every device and drops the link', () {
      registry
        ..replaceAll([seen('tv'), seen('phone', name: 'Phone')])
        ..clear();

      expect(registry.devices, isEmpty);
      expect(registry.isEmpty, isTrue);
      expect(registry.link, ConnectedPlaybackConnection.idle);
    });

    test('a session the server has forgotten is dropped at once', () {
      registry.replaceAll([seen('tv'), seen('phone', name: 'Phone')]);

      expect(registry.forgetSession('session-tv'), isTrue);

      expect(registry.devices.map((device) => device.deviceId), ['phone']);
      // Nothing to forget is not a change, so a caller can use the
      // answer to decide whether to redraw.
      expect(registry.forgetSession('session-tv'), isFalse);
    });

    test('every device it produces names the scope it was observed for', () {
      registry.replaceAll([seen('tv')]);

      expect(registry.devices.single.scope, testScope);
      expect(registry.devices.single.scope, isNot(otherProfileScope));
    });
  });
}
