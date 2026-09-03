import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/features/auth/presentation/accounts/accounts_cubit.dart';

import '../../support/session_fakes.dart';

void main() {
  Future<(TestSessionScope, AccountsCubit)> withTwoAccounts() async {
    final scope = TestSessionScope();
    await scope.cubit.logIn(
      server: fakeServerInfo(baseUrl: 'https://a.example', serverName: 'A'),
      username: 'alice',
      password: 'pw',
    );
    await scope.cubit.logIn(
      server: fakeServerInfo(baseUrl: 'https://b.example', serverName: 'B'),
      username: 'bob',
      password: 'pw',
    );
    final cubit = AccountsCubit(scope.servers, scope.accounts, scope.cubit);
    await cubit.load();
    return (scope, cubit);
  }

  test(
    'load groups saved profiles by server and marks the active one',
    () async {
      final (scope, cubit) = await withTwoAccounts();

      final state = cubit.state as AccountsLoaded;
      expect(state.groups, hasLength(2));
      expect(state.isEmpty, isFalse);
      expect(state.activeAccountId, scope.cubit.activeSession!.account.id);
    },
  );

  test('switchTo changes the active profile and reloads', () async {
    final (scope, cubit) = await withTwoAccounts();
    final alice = (await scope.accounts.all()).firstWhere(
      (a) => a.username == 'alice',
    );

    await cubit.switchTo(alice.id);

    expect((cubit.state as AccountsLoaded).activeAccountId, alice.id);
    expect(scope.cubit.activeSession!.account.id, alice.id);
  });

  test('signOut clears the active profile but keeps the list', () async {
    final (_, cubit) = await withTwoAccounts();

    await cubit.signOut();

    final state = cubit.state as AccountsLoaded;
    expect(state.activeAccountId, isNull);
    expect(state.groups, hasLength(2));
  });

  test('removeAccount drops one profile', () async {
    final (scope, cubit) = await withTwoAccounts();
    final bob = (await scope.accounts.all()).firstWhere(
      (a) => a.username == 'bob',
    );

    await cubit.removeAccount(bob.id);

    final remaining = [
      for (final g in (cubit.state as AccountsLoaded).groups) ...g.accounts,
    ];
    expect(remaining.map((a) => a.username), ['alice']);
  });

  test('removeServer drops the server and its profiles', () async {
    final (scope, cubit) = await withTwoAccounts();
    final serverB = (await scope.servers.all()).firstWhere(
      (s) => s.baseUrl == 'https://b.example',
    );

    await cubit.removeServer(serverB.id);

    expect((cubit.state as AccountsLoaded).groups, hasLength(1));
  });
}
