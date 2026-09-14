import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteQueueEntry.dart';
import 'package:jellyfinity/domain/connected_playback/SyncPlayGroupMember.dart';
import 'package:jellyfinity/domain/connected_playback/SyncPlayGroupUpdate.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';
import 'package:jellyfinity/infrastructure/jellyfin/connected/JellyfinSyncPlayApi.dart';
import 'package:jellyfinity/infrastructure/jellyfin/http/JellyfinHttpClient.dart';

import '../../../support/FakeDioAdapter.dart';
import '../../../support/FakeSessionContext.dart';
import '../../../support/TestLogger.dart';
import '../../../support/connected_playback/FakeJellyfinServer.dart'
    show StaticAuthToken, testSessionTransport, thisDevice;
import '../../../support/connected_playback/FakeJellyfinServer.dart' as fake;
import '../../../support/connected_playback/FakeJellyfinSocket.dart';
import '../../../support/connected_playback/connected_playback_fixtures.dart';

void main() {
  late fake.FakeJellyfinServer server;
  late FakeSessionContext context;
  late List<FakeJellyfinSocket> sockets;
  late JellyfinSyncPlayApi api;
  late FakeDioAdapter restAdapter;

  setUp(() async {
    server = fake.FakeJellyfinServer();
    context = FakeSessionContext();
    sockets = [];
    final transport = testSessionTransport(
      server,
      sockets: sockets,
      socketUrls: [],
      context: context,
    );
    await transport.advertise(testScope);
    // testSessionTransport's socket comes up asynchronously.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    restAdapter = FakeDioAdapter((options) async {
      if (options.path.startsWith('/SyncPlay/')) {
        return textResponseBody('', statusCode: 204);
      }
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(requestOptions: options, statusCode: 404),
      );
    });

    api = JellyfinSyncPlayApi(
      context,
      transport,
      thisDevice,
      const StaticAuthToken('token-1'),
      TestLogger(),
    )..httpClientFactory = (baseUrl) => JellyfinHttpClient(
      baseUrl: baseUrl,
      identity: thisDevice,
      authTokenProvider: const StaticAuthToken('token-1'),
      logger: TestLogger(),
      dio: Dio()..httpClientAdapter = restAdapter,
      maxRetries: 0,
    );

    addTearDown(transport.dispose);
  });

  group('REST calls', () {
    test('createGroup posts to /SyncPlay/New', () async {
      final result = await api.createGroup(testScope);
      expect(result.isOk, isTrue);
      expect(restAdapter.requests.single.path, '/SyncPlay/New');
    });

    test('joinGroup posts the group id to /SyncPlay/Join', () async {
      final result = await api.joinGroup(testScope, 'group-1');
      expect(result.isOk, isTrue);
      expect(restAdapter.requests.single.path, '/SyncPlay/Join');
      expect(restAdapter.requests.single.data, {'GroupId': 'group-1'});
    });

    test('leaveGroup posts to /SyncPlay/Leave', () async {
      final result = await api.leaveGroup(testScope);
      expect(result.isOk, isTrue);
      expect(restAdapter.requests.single.path, '/SyncPlay/Leave');
    });

    test('setQueue sends item ids, start index and start position ticks', () async {
      final result = await api.setQueue(
        testScope,
        entries: [
          RemoteQueueEntry(
            id: MediaId(serverId: testScope.serverId, itemId: 'a'),
            title: 'A',
          ),
          RemoteQueueEntry(
            id: MediaId(serverId: testScope.serverId, itemId: 'b'),
            title: 'B',
          ),
        ],
        startIndex: 1,
        shuffleEnabled: false,
        repeatMode: RepeatMode.off,
        startPosition: const Duration(seconds: 2),
      );

      expect(result.isOk, isTrue);
      final body = restAdapter.requests.single.data as Map;
      expect(body['ItemIds'], ['a', 'b']);
      expect(body['PlayingItemPosition'], 1);
      expect(body['StartPositionTicks'], 20000000);
    });

    test('play, pause and seek reach their own endpoints', () async {
      await api.play(testScope);
      await api.pause(testScope);
      await api.seek(testScope, const Duration(seconds: 5));

      expect(restAdapter.requests.map((r) => r.path), [
        '/SyncPlay/Play',
        '/SyncPlay/Pause',
        '/SyncPlay/Seek',
      ]);
      expect(
        (restAdapter.requests.last.data as Map)['PositionTicks'],
        50000000,
      );
    });
  });

  group('group update decoding', () {
    Future<SyncPlayGroupUpdate> nextUpdate() =>
        api.groupUpdates(testScope).first.timeout(const Duration(seconds: 2));

    test('GroupJoined carries members and the shared queue', () async {
      final future = nextUpdate();
      sockets.single.emit({
        'MessageType': 'SyncPlayGroupUpdate',
        'Data': {
          'GroupId': 'group-1',
          'Type': 'GroupJoined',
          'Data': {
            'GroupName': 'Living Room',
            'Participants': [
              {'SessionId': 'session-tv', 'UserName': 'Living Room TV'},
            ],
            'PlayQueue': [
              {'ItemId': 'a', 'Name': 'Song A'},
            ],
            'PlayingItemPosition': 0,
          },
        },
      });

      final update = await future;
      expect(
        update,
        isA<SyncPlayGroupJoined>()
            .having((u) => u.groupId, 'groupId', 'group-1')
            .having((u) => u.groupName, 'groupName', 'Living Room')
            .having(
              (u) => u.members,
              'members',
              [
                const SyncPlayGroupMember(
                  sessionId: 'session-tv',
                  displayName: 'Living Room TV',
                ),
              ],
            )
            .having((u) => u.queue.single.title, 'queue', 'Song A'),
      );
    });

    test('JoinGroupDenied surfaces the server\'s reason honestly', () async {
      final future = nextUpdate();
      sockets.single.emit({
        'MessageType': 'SyncPlayGroupUpdate',
        'Data': {
          'GroupId': '',
          'Type': 'JoinGroupDenied',
          'Data': {'Reason': 'SyncPlay is disabled on this server.'},
        },
      });

      final update = await future;
      expect(
        update,
        isA<SyncPlayJoinDenied>().having(
          (u) => u.reason,
          'reason',
          'SyncPlay is disabled on this server.',
        ),
      );
    });

    test('an unrecognized update type is never dropped silently', () async {
      final future = nextUpdate();
      sockets.single.emit({
        'MessageType': 'SyncPlayGroupUpdate',
        'Data': {
          'GroupId': 'group-1',
          'Type': 'SomethingFutureVersionsAdd',
          'Data': <String, Object?>{},
        },
      });

      final update = await future;
      expect(
        update,
        isA<UnhandledSyncPlayUpdate>().having(
          (u) => u.updateType,
          'updateType',
          'SomethingFutureVersionsAdd',
        ),
      );
    });
  });
}
