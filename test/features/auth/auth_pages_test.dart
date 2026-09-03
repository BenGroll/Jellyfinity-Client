import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/session/session_cubit.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/design/design.dart';
import 'package:jellyfinity/domain/session/authenticated_user.dart';
import 'package:jellyfinity/features/auth/presentation/login/login_cubit.dart';
import 'package:jellyfinity/features/auth/presentation/login/login_page.dart';
import 'package:jellyfinity/features/auth/presentation/server_setup/server_setup_cubit.dart';
import 'package:jellyfinity/features/auth/presentation/server_setup/server_setup_page.dart';
import 'package:jellyfinity/features/auth/presentation/widgets/inline_error.dart';
import 'package:jellyfinity/infrastructure/jellyfin/http/jellyfin_http_client.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/jellyfin_client_identity.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/jellyfin_server_probe.dart';

import '../../support/fake_dio_adapter.dart';
import '../../support/session_fakes.dart';
import '../../support/test_logger.dart';

const _identity = JellyfinClientIdentity(
  clientName: 'Jellyfinity',
  clientVersion: 'test',
  deviceName: 'Test',
  deviceId: 'dev-1',
);

Widget _host(Widget child) => MaterialApp(theme: AppTheme.dark(), home: child);

void main() {
  testWidgets('server setup shows an inline error for an unreachable address', (
    tester,
  ) async {
    final adapter = FakeDioAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final probe =
        JellyfinServerProbe(
            _identity,
            const NoAuthTokenProvider(),
            TestLogger(),
          )
          ..httpClientFactory = (baseUrl) => JellyfinHttpClient(
            baseUrl: baseUrl,
            identity: _identity,
            authTokenProvider: const NoAuthTokenProvider(),
            logger: TestLogger(),
            dio: Dio()..httpClientAdapter = adapter,
            maxRetries: 0,
          );

    await tester.pumpWidget(
      _host(ServerSetupPage(cubit: ServerSetupCubit(probe))),
    );

    await tester.enterText(
      find.byType(TextField),
      'https://unreachable.example',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(InlineError), findsOneWidget);
  });

  testWidgets('login shows an inline error for bad credentials', (
    tester,
  ) async {
    final scope = TestSessionScope(
      authResult: const Result<AuthenticatedUser>.err(
        UnauthorizedFailure('Incorrect username or password.'),
      ),
    );
    addTearDown(scope.cubit.close);

    await tester.pumpWidget(
      _host(
        BlocProvider<SessionCubit>.value(
          value: scope.cubit,
          child: LoginPage(
            server: fakeServerInfo(),
            cubit: LoginCubit(scope.cubit),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'alice');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.tap(find.widgetWithText(AppButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect username or password.'), findsOneWidget);
  });
}
