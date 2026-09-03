import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/session/authenticated_user.dart';
import 'package:jellyfinity/features/auth/presentation/login/login_cubit.dart';

import '../../support/session_fakes.dart';

void main() {
  LoginCubit cubitFor(TestSessionScope scope) =>
      LoginCubit(scope.cubit)..forServer(fakeServerInfo());

  test(
    'empty fields produce an error without calling the authenticator',
    () async {
      final scope = TestSessionScope();
      final cubit = cubitFor(scope);

      await cubit.submit(username: '  ', password: '');

      expect(cubit.state, isA<LoginError>());
      expect(scope.authenticator.calls, isEmpty);
    },
  );

  test(
    'a successful sign-in leaves no error state and signs the app in',
    () async {
      final scope = TestSessionScope();
      final cubit = cubitFor(scope);

      await cubit.submit(username: 'alice', password: 'pw');

      expect(cubit.state, isNot(isA<LoginError>()));
      expect(scope.cubit.activeSession!.account.username, 'alice');
    },
  );

  test(
    'bad credentials surface as a LoginError carrying the failure',
    () async {
      final scope = TestSessionScope(
        authResult: const Result<AuthenticatedUser>.err(
          UnauthorizedFailure('Incorrect username or password.'),
        ),
      );
      final cubit = cubitFor(scope);

      await cubit.submit(username: 'alice', password: 'wrong');

      expect(cubit.state, isA<LoginError>());
      expect((cubit.state as LoginError).failure, isA<UnauthorizedFailure>());
    },
  );

  test('the username is trimmed before authenticating', () async {
    final scope = TestSessionScope();
    final cubit = cubitFor(scope);

    await cubit.submit(username: '  alice  ', password: 'pw');

    expect(scope.authenticator.calls.single.username, 'alice');
  });
}
