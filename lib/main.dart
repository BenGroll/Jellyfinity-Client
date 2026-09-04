import 'app/JellyfinityApp.dart';
import 'app/bootstrap.dart';
import 'app/di/service_locator.dart';
import 'app/router/AppRouter.dart';
import 'app/session/SessionCubit.dart';

Future<void> main() async {
  await bootstrap(
    builder: () => JellyfinityApp(
      router: getIt<AppRouter>().config,
      session: getIt<SessionCubit>(),
    ),
  );
}
