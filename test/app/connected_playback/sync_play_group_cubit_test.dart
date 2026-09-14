import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/SyncPlayGroupCubit.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteQueueEntry.dart';
import 'package:jellyfinity/domain/connected_playback/SyncPlayGroupMember.dart';
import 'package:jellyfinity/domain/connected_playback/SyncPlayGroupUpdate.dart';
import 'package:jellyfinity/domain/connected_playback/sync_play_group_status.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/media/Track.dart';

import '../../support/connected_playback/connected_playback_fixtures.dart';
import '../../support/connected_playback/FakeSyncPlayTransport.dart';
import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/session_fakes.dart';

void main() {
  Track track(String id) => Track(
    id: MediaId(serverId: testScope.serverId, itemId: id),
    name: 'Track $id',
    duration: const Duration(minutes: 3),
  );

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  late FakeSyncPlayTransport transport;
  late FakeMusicLibraryRepository library;
  late FakePlaybackEngine engine;
  late PlaybackCubit playback;
  late SyncPlayGroupCubit cubit;

  setUp(() {
    transport = FakeSyncPlayTransport();
    library = FakeMusicLibraryRepository()
      ..trackList = [track('a'), track('b'), track('c')];
    engine = FakePlaybackEngine();
    playback = fakePlaybackCubit(engine: engine);
    cubit = SyncPlayGroupCubit(
      transport,
      playback,
      library,
      fakeSessionCubit(signedIn: fakeAuthSession()),
    );
  });

  tearDown(() async {
    await cubit.close();
    await playback.close();
    await transport.dispose();
  });

  test('starts out of any group', () {
    expect(cubit.state.status, SyncPlayGroupStatus.none);
  });

  test('creating a group marks it joining, then joined once the server '
      'confirms', () async {
    final future = cubit.createGroup();
    expect(cubit.state.status, SyncPlayGroupStatus.joining);

    transport.emit(
      const SyncPlayGroupJoined(
        groupId: 'group-1',
        groupName: 'Living Room',
        members: [],
      ),
    );
    await future;
    await settle();

    expect(cubit.state.status, SyncPlayGroupStatus.joined);
    expect(cubit.state.groupId, 'group-1');
    expect(cubit.state.groupName, 'Living Room');
    expect(transport.calls, contains('createGroup'));
  });

  test('a join the server refuses is a visible failure, not a silent '
      'no-op', () async {
    final future = cubit.createGroup();
    transport.emit(
      const SyncPlayJoinDenied('SyncPlay is disabled on this server.'),
    );
    await future;
    await settle();

    expect(cubit.state.status, SyncPlayGroupStatus.failed);
    expect(
      cubit.state.failureMessage,
      'SyncPlay is disabled on this server.',
    );
  });

  test('a request that cannot even reach the server also fails visibly', () async {
    transport.nextCallFails = true;
    await cubit.createGroup();
    await settle();

    expect(cubit.state.status, SyncPlayGroupStatus.failed);
  });

  test('leaving releases membership and calls the server', () async {
    transport.emit(
      const SyncPlayGroupJoined(
        groupId: 'group-1',
        groupName: 'Living Room',
        members: [],
      ),
    );
    await settle();
    expect(cubit.state.status, SyncPlayGroupStatus.joined);

    await cubit.leave();

    expect(transport.calls, contains('leaveGroup'));
    expect(cubit.state.status, SyncPlayGroupStatus.none);
  });

  test('the server ending this device\'s membership is treated the same '
      'as this device leaving', () async {
    transport.emit(
      const SyncPlayGroupJoined(
        groupId: 'group-1',
        groupName: 'Living Room',
        members: [],
      ),
    );
    await settle();

    transport.emit(const SyncPlayGroupLeft());
    await settle();

    expect(cubit.state.status, SyncPlayGroupStatus.none);
  });

  test('members joining and leaving update the visible roster', () async {
    transport.emit(
      const SyncPlayGroupJoined(
        groupId: 'group-1',
        groupName: 'Living Room',
        members: [],
      ),
    );
    await settle();

    transport.emit(
      const SyncPlayUserJoined(
        SyncPlayGroupMember(sessionId: 'session-tv', displayName: 'TV'),
      ),
    );
    await settle();
    expect(cubit.state.members, hasLength(1));

    transport.emit(const SyncPlayUserLeft('session-tv'));
    await settle();
    expect(cubit.state.members, isEmpty);
  });

  test('playOnAllDevices sends this device\'s current queue to the group, '
      'creating one first', () async {
    await playback.playNow([track('a'), track('b')], startIndex: 0);
    await settle();

    final future = cubit.playOnAllDevices();
    transport.emit(
      const SyncPlayGroupJoined(
        groupId: 'group-1',
        groupName: 'Living Room',
        members: [],
      ),
    );
    await future;
    await settle();

    expect(transport.calls, contains('createGroup'));
    expect(transport.calls.any((c) => c.startsWith('setQueue(2')), isTrue);
  });

  test('a queue update from the group loads the real local queue — the '
      'one control path into PlaybackCubit', () async {
    transport.emit(
      const SyncPlayGroupJoined(
        groupId: 'group-1',
        groupName: 'Living Room',
        members: [],
      ),
    );
    await settle();

    transport.emit(
      SyncPlayQueueUpdated(
        entries: [
          RemoteQueueEntry(
            id: MediaId(serverId: testScope.serverId, itemId: 'a'),
            title: 'a',
          ),
          RemoteQueueEntry(
            id: MediaId(serverId: testScope.serverId, itemId: 'b'),
            title: 'b',
          ),
        ],
        startIndex: 1,
      ),
    );
    await settle();

    expect(playback.state.queue.currentIndex, 1);
    expect(playback.state.hasQueue, isTrue);
  });

  test('a transport update never touches this device\'s own volume', () async {
    engine.systemVolumeValue = 0.2;
    await playback.setSystemVolume(0.6);
    engine.calls.clear();
    transport.emit(
      const SyncPlayGroupJoined(
        groupId: 'group-1',
        groupName: 'Living Room',
        members: [],
      ),
    );
    await settle();

    transport.emit(
      const SyncPlayTransportUpdated(
        isPlaying: true,
        position: Duration.zero,
      ),
    );
    await settle();

    expect(engine.calls, isNot(contains('setSystemVolume(0.6)')));
    expect(playback.state.systemVolume, 0.6);
  });
}
