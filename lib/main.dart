import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/di/service_locator.dart';
import 'app/router/app_router.dart';
import 'app/session/session_cubit.dart';

Future<void> main() async {
  await bootstrap(
    builder: () => JellyfinityApp(
      router: getIt<AppRouter>().config,
      session: getIt<SessionCubit>(),
    ),
  );
}
