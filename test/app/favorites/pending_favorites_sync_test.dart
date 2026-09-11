import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/favorites/FavoritesRevisionCubit.dart';
import 'package:jellyfinity/app/favorites/PendingFavoritesSync.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinFavoritesRepository.dart';

import '../../support/FakeDioAdapter.dart';
import '../../support/FakeSessionContext.dart';
import '../../support/media_fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/session_fakes.dart';
import '../../support/TestLogger.dart';

const _account = 'server-1/user-1';
const _albumId = MediaId(serverId: 'server-1', itemId: 'album-1');

/// A [FakeDioAdapter] that answers every request with success.
FakeDioAdapter _ok() => FakeDioAdapter((_) async => jsonResponseBody({}));

/// One whose every request fails, as a real rejection from the server
/// would (not a connection error — that is what "offline" already covers).
FakeDioAdapter _rejecting() => FakeDioAdapter(
  (_) async => jsonResponseBody({'error': 'nope'}, statusCode: 404),
);

void main() {
  late RecordingMediaCacheStore cache;
  late FakeOfflineMode offline;
  late FakeSessionContext context;
  late FavoritesRevisionCubit revision;
  late TestSessionScope scope;

  setUp(() {
    cache = RecordingMediaCacheStore();
    offline = FakeOfflineMode(connected: false);
    context = FakeSessionContext();
    revision = FavoritesRevisionCubit();
    scope = TestSessionScope();
  });

  tearDown(() async {
    await revision.close();
    await scope.cubit.close();
    await offline.dispose();
  });

  PendingFavoritesSync sync(FakeDioAdapter adapter) {
    final instance = PendingFavoritesSync(
      JellyfinFavoritesRepository(testMediaApi(adapter, context: context)),
      cache,
      offline,
      context,
      scope.cubit,
      revision,
      TestLogger(),
    );
    addTearDown(instance.dispose);
    return instance;
  }

  test(
    'replays a pending intent once connectivity returns, and clears it',
    () async {
      await cache.recordPendingFavorite(
        _account,
        _albumId,
        MediaKind.album,
        favorite: true,
      );

      sync(_ok()).start();
      offline.setConnected(true);
      await pumpEventQueue();

      expect(await cache.pendingFavorites(_account), isEmpty);
    },
  );

  test('bumps the revision cubit once a replay succeeds', () async {
    await cache.recordPendingFavorite(
      _account,
      _albumId,
      MediaKind.album,
      favorite: true,
    );
    final before = revision.state;

    sync(_ok()).start();
    offline.setConnected(true);
    await pumpEventQueue();

    expect(revision.state, greaterThan(before));
  });

  test(
    'reconciles immediately on start when already online, for a session '
    'restored after the app was closed offline',
    () async {
      await cache.recordPendingFavorite(
        _account,
        _albumId,
        MediaKind.album,
        favorite: true,
      );
      offline.setConnected(true);

      sync(_ok()).start();
      await pumpEventQueue();

      expect(await cache.pendingFavorites(_account), isEmpty);
    },
  );

  test(
    'a server rejection leaves the intent pending and retryable',
    () async {
      await cache.recordPendingFavorite(
        _account,
        _albumId,
        MediaKind.album,
        favorite: true,
      );

      sync(_rejecting()).start();
      offline.setConnected(true);
      await pumpEventQueue();

      final pending = await cache.pendingFavorites(_account);
      expect(pending.single.id, _albumId);
    },
  );

  test('does nothing while still offline', () async {
    await cache.recordPendingFavorite(
      _account,
      _albumId,
      MediaKind.album,
      favorite: true,
    );

    sync(_ok()).start();
    await pumpEventQueue();

    expect(await cache.pendingFavorites(_account), hasLength(1));
  });

  test(
    "never replays into another profile's pending intents",
    () async {
      const otherAccount = 'server-1/user-2';
      await cache.recordPendingFavorite(
        otherAccount,
        _albumId,
        MediaKind.album,
        favorite: true,
      );
      // The active session (server-1/user-1) has nothing of its own.

      sync(_ok()).start();
      offline.setConnected(true);
      await pumpEventQueue();

      // The other profile's intent is untouched — it is only ever read
      // and replayed while it is the one signed in.
      expect(await cache.pendingFavorites(otherAccount), hasLength(1));
    },
  );

  test(
    'reconciles again once a different profile with its own pending '
    'intent signs in',
    () async {
      const otherAccount = 'server-1/user-2';
      await cache.recordPendingFavorite(
        otherAccount,
        _albumId,
        MediaKind.album,
        favorite: true,
      );
      offline.setConnected(true);

      sync(_ok()).start();
      await pumpEventQueue();
      // Nobody was signed in yet, so nothing was reconciled.
      expect(await cache.pendingFavorites(otherAccount), hasLength(1));

      context.userId = 'user-2';
      await scope.signIn();
      await pumpEventQueue();

      expect(await cache.pendingFavorites(otherAccount), isEmpty);
    },
  );
}
