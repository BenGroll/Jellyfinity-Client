import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/session/session_status.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/session/authenticated_user.dart';

import '../../support/session_fakes.dart';

void main() {
  test('starts in the restoring state', () {
    final scope = TestSessionScope();
    addTearDown(scope.cubit.close);

    expect(scope.cubit.state.status, SessionStatus.unknown);
  });

  test('restore with no saved session ends signed out', () async {
    final scope = TestSessionScope();
    addTearDown(scope.cubit.close);

    await scope.cubit.restore();

    expect(scope.cubit.state.status, SessionStatus.unauthenticated);
  });

  test('restore with a saved session ends signed in', () async {
    final scope = TestSessionScope();
    await scope.manager.logIn(
      validatedServer: fakeServerInfo(),
      username: 'alice',
      password: 'pw',
    );
    final restarted = TestSessionScope(
      servers: scope.servers,
      accounts: scope.accounts,
      credentials: scope.credentials,
    );
    addTearDown(restarted.cubit.close);

    await restarted.cubit.restore();

    expect(restarted.cubit.state.status, SessionStatus.authenticated);
    expect(restarted.cubit.activeSession!.account.username, 'alice');
  });

  test('a successful logIn emits signed in and returns Ok', () async {
    final scope = TestSessionScope();
    addTearDown(scope.cubit.close);
    await scope.cubit.restore();

    final result = await scope.cubit.logIn(
      server: fakeServerInfo(),
      username: 'alice',
      password: 'pw',
    );

    expect(result.isOk, isTrue);
    expect(scope.cubit.state.status, SessionStatus.authenticated);
  });

  test('a failed logIn stays signed out and returns the failure', () async {
    final scope = TestSessionScope(
      authResult: const Result<AuthenticatedUser>.err(
        UnauthorizedFailure('Incorrect username or password.'),
      ),
    );
    addTearDown(scope.cubit.close);
    await scope.cubit.restore();

    final result = await scope.cubit.logIn(
      server: fakeServerInfo(),
      username: 'alice',
      password: 'wrong',
    );

    expect(result.failureOrNull, isA<UnauthorizedFailure>());
    expect(scope.cubit.state.status, SessionStatus.unauthenticated);
  });

  test('handleUnauthorized signs out and remembers the profile', () async {
    final scope = TestSessionScope();
    addTearDown(scope.cubit.close);
    await scope.cubit.logIn(
      server: fakeServerInfo(),
      username: 'alice',
      password: 'pw',
    );
    final accountId = scope.cubit.activeSession!.account.id;

    await scope.cubit.handleUnauthorized();

    expect(scope.cubit.state.status, SessionStatus.unauthenticated);
    expect(scope.cubit.state.lastAccountId, accountId);
  });

  test('signOut returns to the unauthenticated state', () async {
    final scope = TestSessionScope();
    addTearDown(scope.cubit.close);
    await scope.cubit.logIn(
      server: fakeServerInfo(),
      username: 'alice',
      password: 'pw',
    );

    await scope.cubit.signOut();

    expect(scope.cubit.state.status, SessionStatus.unauthenticated);
    expect(scope.cubit.activeSession, isNull);
  });
}
