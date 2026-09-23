import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackScope.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceCapabilities.dart';
import 'package:jellyfinity/domain/connected_playback/PlaybackOwnership.dart';
import 'package:jellyfinity/domain/connected_playback/ProtocolVersion.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteCommand.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteQueueEntry.dart';
import 'package:jellyfinity/domain/connected_playback/StateRevision.dart';
import 'package:jellyfinity/domain/connected_playback/device_reachability.dart';
import 'package:jellyfinity/domain/connected_playback/remote_command_kind.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/media/MediaImage.dart';
import 'package:jellyfinity/domain/playback/QueueEntry.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';
import 'package:jellyfinity/domain/media/media_availability.dart';

import '../../support/connected_playback/connected_playback_fixtures.dart';

void main() {
  group('ConnectedPlaybackScope', () {
    test('round-trips through its key', () {
      expect(ConnectedPlaybackScope.tryParse(testScope.key), testScope);
    });

    test('refuses a malformed key rather than inventing a scope', () {
      expect(ConnectedPlaybackScope.tryParse('server-only'), isNull);
      expect(ConnectedPlaybackScope.tryParse('/user'), isNull);
      expect(ConnectedPlaybackScope.tryParse('server/'), isNull);
      expect(ConnectedPlaybackScope.tryParse(null), isNull);
    });

    test('distinguishes the same user on two servers', () {
      expect(testScope, isNot(otherServerScope));
      expect(testScope, isNot(otherProfileScope));
    });
  });

  group('ConnectedDevice', () {
    test('distinguishes duplicate names with a hint', () {
      final fireTv = device(name: 'Living Room', nameHint: 'Fire TV');
      final windows = device(name: 'Living Room', nameHint: 'Windows');

      expect(fireTv.displayName, 'Living Room (Fire TV)');
      expect(windows.displayName, 'Living Room (Windows)');
      expect(device(name: 'Kitchen').displayName, 'Kitchen');
    });

    test('is never a transfer target for itself', () {
      expect(device(isThisDevice: true).canReceiveTransfer, isFalse);
      expect(device(isThisDevice: true).canBeControlled, isFalse);
    });

    test('is not offered while only presence is working', () {
      // The invariant: a device without working command delivery may be
      // listed, but never presented as a ready handoff target.
      final polled = device(reachability: DeviceReachability.presenceOnly);

      expect(polled.canReceiveTransfer, isFalse);
      expect(polled.reachability.isListable, isTrue);
    });

    test('is not offered when it speaks another protocol major version', () {
      final old = device(protocolVersion: const ProtocolVersion(0, 9));

      expect(old.canReceiveTransfer, isFalse);
    });

    test('is dropped from the list once stale', () {
      expect(DeviceReachability.stale.isListable, isFalse);
    });

    test('separates its stable identity from its ephemeral session', () {
      final before = device(deviceId: 'device-tv', sessionId: 'session-a');
      final after = before.copyWith(sessionId: 'session-b');

      // Same device, new session — the pairing that lets a remembered
      // target survive a reconnect and a command still be routable.
      expect(after.deviceId, before.deviceId);
      expect(after, isNot(before));
    });
  });

  group('DeviceCapabilities', () {
    test('a player that cannot take a queue cannot receive a transfer', () {
      const playerWithoutQueue = DeviceCapabilities(
        canPlay: true,
        canControl: false,
        acceptedCommands: {RemoteCommandKind.play, RemoteCommandKind.pause},
      );

      expect(playerWithoutQueue.canPlay, isTrue);
      expect(playerWithoutQueue.canReceiveTransfer, isFalse);
    });

    test('negotiation is an intersection, in both directions', () {
      const target = DeviceCapabilities(
        canPlay: true,
        canControl: true,
        acceptedCommands: {RemoteCommandKind.play, RemoteCommandKind.setVolume},
      );

      expect(
        target.negotiate({RemoteCommandKind.play, RemoteCommandKind.next}),
        {RemoteCommandKind.play},
      );
      // A peer accepting more than this build can compose gains nothing
      // by being offered it.
      expect(target.negotiate(const {}), isEmpty);
    });

    test('keeps advertised capability tokens it does not understand', () {
      const future = DeviceCapabilities(
        canPlay: true,
        canControl: true,
        unknownCapabilities: ['video', 'outputSwitching'],
      );

      expect(future.unknownCapabilities, ['video', 'outputSwitching']);
    });

    test('compares equal regardless of advertised command order', () {
      const first = DeviceCapabilities(
        canPlay: true,
        canControl: true,
        acceptedCommands: {RemoteCommandKind.play, RemoteCommandKind.pause},
      );
      const second = DeviceCapabilities(
        canPlay: true,
        canControl: true,
        acceptedCommands: {RemoteCommandKind.pause, RemoteCommandKind.play},
      );

      // A re-advertisement that reorders a set is not a change and must
      // not redraw a device picker.
      expect(first, second);
    });
  });

  group('PlaybackOwnership', () {
    const scope = testScope;

    test('a device with nothing claimed owns its own queue', () {
      final ownership = PlaybackOwnership.unclaimed(
        scope: scope,
        localSessionId: 'session-phone',
      );

      expect(ownership.ownsLocalQueue, isTrue);
      expect(ownership.shouldShowRemoteControls, isFalse);
    });

    test('the player owns the authoritative queue', () {
      final ownership = PlaybackOwnership.local(
        scope: scope,
        localSessionId: 'session-phone',
      );

      expect(ownership.isLocal, isTrue);
      expect(ownership.ownsLocalQueue, isTrue);
    });

    test('a controller must not write its local queue', () {
      final ownership = PlaybackOwnership.unclaimed(
        scope: scope,
        localSessionId: 'session-phone',
      ).claimedBy('session-tv', deviceName: 'Living Room');

      expect(ownership.isRemote, isTrue);
      expect(ownership.ownsLocalQueue, isFalse);
      expect(ownership.ownerDeviceName, 'Living Room');
    });

    test('releasing hands the local queue back', () {
      final ownership = PlaybackOwnership.unclaimed(
        scope: scope,
        localSessionId: 'session-phone',
      ).claimedBy('session-tv').released();

      expect(ownership.ownsLocalQueue, isTrue);
    });
  });

  group('RemoteQueueEntry', () {
    test('round-trips every field it carries', () {
      final full = RemoteQueueEntry(
        id: const MediaId(serverId: 'server-1', itemId: 'track-1'),
        title: 'So What',
        artist: 'Miles Davis',
        albumId: const MediaId(serverId: 'server-1', itemId: 'album-1'),
        albumName: 'Kind of Blue',
        duration: const Duration(minutes: 9, seconds: 22),
        image: const MediaImage(
          itemId: MediaId(serverId: 'server-1', itemId: 'album-1'),
          kind: MediaImageKind.primary,
          tag: 'abc123',
          aspectRatio: 1,
        ),
      );

      expect(
        RemoteQueueEntry.tryDecode(jsonDecode(jsonEncode(full.toJson()))),
        full,
      );
    });

    test('drops an unreadable image rather than the whole row', () {
      final decoded = RemoteQueueEntry.tryDecode({
        'id': 'server-1:track-1',
        'title': 'So What',
        'image': {'tag': 'abc123'},
      });

      expect(decoded, isNotNull);
      expect(decoded!.image, isNull);
    });

    test('refuses a row with no id or no title', () {
      expect(RemoteQueueEntry.tryDecode({'title': 'So What'}), isNull);
      expect(RemoteQueueEntry.tryDecode({'id': 'server-1:t'}), isNull);
      expect(RemoteQueueEntry.tryDecode('not a map'), isNull);
    });

    test('does not carry one device availability verdict to another', () {
      final local = QueueEntry(
        id: const MediaId(serverId: 'server-1', itemId: 'track-1'),
        title: 'So What',
        availability: MediaAvailability.remoteUnavailable,
        failureMessage: 'This phone could not decode it',
      );

      final crossed = RemoteQueueEntry.fromQueueEntry(local).toQueueEntry();

      // A track this device could not play may play perfectly on the
      // other one; inheriting the verdict would carry one device's bad
      // luck onto another.
      expect(crossed.availability, MediaAvailability.remoteOnly);
      expect(crossed.failureMessage, isNull);
    });
  });

  group('command codec', () {
    RemoteCommand decoded(RemoteCommand command) {
      final decoding = decodeRemoteCommand(
        jsonDecode(jsonEncode(command.toPayload())) as Map<String, Object?>,
        scope: testScope,
      );
      return (decoding as DecodedRemoteCommand).command;
    }

    test('every command kind survives a round trip', () {
      // The exhaustiveness guard: a command added without a decode
      // branch fails here rather than silently becoming "unsupported" on
      // every peer.
      final samples = <RemoteCommandKind, RemoteCommand>{
        for (final kind in [
          RemoteCommandKind.play,
          RemoteCommandKind.pause,
          RemoteCommandKind.playPause,
          RemoteCommandKind.stop,
          RemoteCommandKind.next,
          RemoteCommandKind.previous,
          RemoteCommandKind.requestSnapshot,
        ])
          kind: SimpleRemoteCommand(
            id: 'c-${kind.wireName}',
            scope: testScope,
            targetSessionId: 'session-tv',
            kind: kind,
          ),
        RemoteCommandKind.seek: const SeekCommand(
          id: 'c-seek',
          scope: testScope,
          targetSessionId: 'session-tv',
          position: Duration(seconds: 42),
        ),
        RemoteCommandKind.setVolume: const SetVolumeCommand(
          id: 'c-volume',
          scope: testScope,
          targetSessionId: 'session-tv',
          volume: 0.4,
        ),
        RemoteCommandKind.setShuffle: const SetShuffleCommand(
          id: 'c-shuffle',
          scope: testScope,
          targetSessionId: 'session-tv',
          enabled: true,
        ),
        RemoteCommandKind.setRepeat: const SetRepeatCommand(
          id: 'c-repeat',
          scope: testScope,
          targetSessionId: 'session-tv',
          repeatMode: RepeatMode.all,
        ),
        RemoteCommandKind.setQueue: SetQueueCommand(
          id: 'c-queue',
          scope: testScope,
          targetSessionId: 'session-tv',
          entries: entries(2),
          startIndex: 1,
          startPosition: const Duration(seconds: 12),
          shuffleEnabled: true,
          repeatMode: RepeatMode.one,
          originName: 'Late Night',
          startPlaying: false,
        ),
        RemoteCommandKind.appendToQueue: AppendToQueueCommand(
          id: 'c-append',
          scope: testScope,
          targetSessionId: 'session-tv',
          entries: entries(1),
          expectedRevision: const StateRevision(3),
        ),
        RemoteCommandKind.joinSyncGroup: const JoinSyncGroupCommand(
          id: 'c-join-sync',
          scope: testScope,
          targetSessionId: 'session-tv',
          groupId: 'group-1',
        ),
        RemoteCommandKind.takeControl: const TakeControlCommand(
          id: 'c-take-control',
          scope: testScope,
          targetSessionId: 'session-tv',
          controllerOfSessionId: 'session-phone',
        ),
        RemoteCommandKind.removeQueueEntry: const RemoveQueueEntryCommand(
          id: 'c-remove',
          scope: testScope,
          targetSessionId: 'session-tv',
          index: 2,
          expectedRevision: StateRevision(3),
        ),
        RemoteCommandKind.moveQueueEntry: const MoveQueueEntryCommand(
          id: 'c-move',
          scope: testScope,
          targetSessionId: 'session-tv',
          fromIndex: 0,
          toIndex: 2,
          expectedRevision: StateRevision(3),
        ),
        RemoteCommandKind.jumpToQueueEntry: const JumpToQueueEntryCommand(
          id: 'c-jump',
          scope: testScope,
          targetSessionId: 'session-tv',
          index: 1,
          expectedRevision: StateRevision(3),
        ),
      };

      expect(
        samples.keys.toSet(),
        RemoteCommandKind.values.toSet(),
        reason: 'every command kind needs a round-trip sample',
      );
      for (final entry in samples.entries) {
        expect(decoded(entry.value), entry.value, reason: entry.key.wireName);
      }
    });

    test('an unknown command keeps enough to be refused by name', () {
      final decoding = decodeRemoteCommand(const {
        'commandId': 'c-future',
        'target': 'session-tv',
        'command': 'setCrossfade',
      }, scope: testScope);

      final unsupported = decoding as UnsupportedRemoteCommand;
      expect(unsupported.commandId, 'c-future');
      expect(unsupported.targetSessionId, 'session-tv');
    });

    test('a payload with no id has nothing to answer about', () {
      expect(
        decodeRemoteCommand(const {'command': 'play'}, scope: testScope),
        isA<UnreadableRemoteCommand>(),
      );
    });

    test('a queue with one unreadable entry fails whole, never truncated', () {
      final decoding = decodeRemoteCommand({
        'commandId': 'c-queue',
        'target': 'session-tv',
        'command': 'setQueue',
        'startIndex': 0,
        'entries': [
          entry('t0').toJson(),
          const {'title': 'no id'},
        ],
      }, scope: testScope);

      // Entries are never silently removed: a queue one track shorter
      // than the one the listener transferred is exactly what the arc
      // forbids.
      expect(decoding, isA<UnreadableRemoteCommand>());
    });

    test('a structural command without a revision is unreadable', () {
      expect(
        decodeRemoteCommand(const {
          'commandId': 'c-remove',
          'target': 'session-tv',
          'command': 'removeQueueEntry',
          'index': 1,
        }, scope: testScope),
        isA<UnreadableRemoteCommand>(),
      );
    });
  });

  group('StateRevision', () {
    test('orders and increments monotonically', () {
      expect(StateRevision.initial.next, const StateRevision(1));
      expect(const StateRevision(3) > const StateRevision(2), isTrue);
      expect(const StateRevision(2) >= const StateRevision(2), isTrue);
      expect(const StateRevision(1) < const StateRevision(2), isTrue);
    });

    test('parses only non-negative integers', () {
      expect(StateRevision.tryParse(4), const StateRevision(4));
      expect(StateRevision.tryParse('4'), const StateRevision(4));
      expect(StateRevision.tryParse(-1), isNull);
      expect(StateRevision.tryParse('later'), isNull);
      expect(StateRevision.tryParse(null), isNull);
    });
  });
}
