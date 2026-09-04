import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/session/AuthenticatedUser.dart';

import '../../support/session_fakes.dart';

void main() {
  test('logIn persists the server, the profile and the token, and '
      'makes it active', () async {
    final scope = TestSessionScope();

    final result = await scope.manager.logIn(
      validatedServer: fakeServerInfo(),
      username: 'alice',
      password: 'pw',
    );

    expect(result.isOk, isTrue);
    final session = result.valueOrNull!;
    expect(session.account.username, 'alice');
    expect(session.accessToken, 'token-alice');

    expect(await scope.servers.all(), hasLength(1));
    expect(await scope.accounts.activeAccountId(), session.account.id);
    expect(scope.credentials.tokens[session.account.id], 'token-alice');
    expect(scope.manager.currentToken, 'token-alice');
  });

  test('re-logging in as the same user on the same server reuses the '
      'saved profile', () async {
    final scope = TestSessionScope();
    await scope.manager.logIn(
      validatedServer: fakeServerInfo(),
      username: 'alice',
      password: 'pw',
    );
    await scope.manager.logIn(
      validatedServer: fakeServerInfo(),
      username: 'alice',
      password: 'pw',
    );

    expect(await scope.servers.all(), hasLength(1));
    expect(await scope.accounts.all(), hasLength(1));
  });

  test('restore rebuilds the active session from storage', () async {
    final scope = TestSessionScope();
    await scope.manager.logIn(
      validatedServer: fakeServerInfo(),
      username: 'alice',
      password: 'pw',
    );

    // A fresh manager over the same stores, as a cold start would build.
    final restarted = TestSessionScope(
      servers: scope.servers,
      accounts: scope.accounts,
      credentials: scope.credentials,
    );

    final restored = await restarted.manager.restore();

    expect(restored, isNotNull);
    expect(restored!.account.username, 'alice');
    expect(restored.accessToken, 'token-alice');
  });

  test('restore does not call the authenticator or need the network', () async {
    final scope = TestSessionScope();
    await scope.manager.logIn(
      validatedServer: fakeServerInfo(),
      username: 'alice',
      password: 'pw',
    );
    scope.authenticator.calls.clear();

    // Even with the authenticator rigged to fail, restore succeeds — it
    // only reads storage. This is the "launch even if the server is
    // offline" requirement.
    scope.authenticator.result = const Result.err(
      RecoverableFailure('server unreachable'),
    );

    final restored = await scope.manager.restore();

    expect(restored, isNotNull);
    expect(scope.authenticator.calls, isEmpty);
  });

  test(
    'restore signs out and clears the pointer when the token is gone',
    () async {
      final scope = TestSessionScope();
      await scope.manager.logIn(
        validatedServer: fakeServerInfo(),
        username: 'alice',
        password: 'pw',
      );
      scope.credentials.tokens.clear(); // secure entry lost

      final restored = await scope.manager.restore();

      expect(restored, isNull);
      expect(await scope.accounts.activeAccountId(), isNull);
    },
  );

  test('switchTo activates another saved profile', () async {
    final scope = TestSessionScope();
    final first = (await scope.manager.logIn(
      validatedServer: fakeServerInfo(baseUrl: 'https://a.example'),
      username: 'alice',
      password: 'pw',
    )).valueOrNull!;
    final second = (await scope.manager.logIn(
      validatedServer: fakeServerInfo(baseUrl: 'https://b.example'),
      username: 'bob',
      password: 'pw',
    )).valueOrNull!;

    expect(scope.manager.current!.account.id, second.account.id);

    final switched = await scope.manager.switchTo(first.account.id);

    expect(switched.valueOrNull!.account.id, first.account.id);
    expect(await scope.accounts.activeAccountId(), first.account.id);
  });

  test('logOut clears the token but keeps the saved profile', () async {
    final scope = TestSessionScope();
    final session = (await scope.manager.logIn(
      validatedServer: fakeServerInfo(),
      username: 'alice',
      password: 'pw',
    )).valueOrNull!;

    await scope.manager.logOut();

    expect(scope.manager.current, isNull);
    expect(await scope.accounts.activeAccountId(), isNull);
    expect(scope.credentials.tokens[session.account.id], isNull);
    expect(await scope.accounts.all(), hasLength(1)); // profile kept
  });

  test('removeServer drops its profiles and their tokens', () async {
    final scope = TestSessionScope();
    final session = (await scope.manager.logIn(
      validatedServer: fakeServerInfo(),
      username: 'alice',
      password: 'pw',
    )).valueOrNull!;

    await scope.manager.removeServer(session.server.id);

    expect(await scope.servers.all(), isEmpty);
    expect(await scope.accounts.all(), isEmpty);
    expect(scope.credentials.tokens, isEmpty);
    expect(scope.manager.current, isNull);
    // Cached metadata for that library names a server that is gone; it
    // could never be shown or refreshed again.
    expect(scope.mediaCache.clearedServers, [session.server.id]);
  });

  test('a failed authentication changes nothing', () async {
    final scope = TestSessionScope(
      authResult: const Result<AuthenticatedUser>.err(
        UnauthorizedFailure('Incorrect username or password.'),
      ),
    );

    final result = await scope.manager.logIn(
      validatedServer: fakeServerInfo(),
      username: 'alice',
      password: 'wrong',
    );

    expect(result.failureOrNull, isA<UnauthorizedFailure>());
    expect(await scope.servers.all(), isEmpty);
    expect(await scope.accounts.all(), isEmpty);
    expect(scope.manager.current, isNull);
  });
}
