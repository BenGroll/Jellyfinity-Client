import 'app/JellyfinityApp.dart';
import 'app/bootstrap.dart';
import 'app/di/service_locator.dart';
import 'app/navigation/MediaScopeCubit.dart';
import 'app/playback/PlaybackCubit.dart';
import 'app/router/AppRouter.dart';
import 'app/session/SessionCubit.dart';
import 'app/settings/SettingsCubit.dart';

Future<void> main() async {
  await bootstrap(
    builder: () => JellyfinityApp(
      router: getIt<AppRouter>().config,
      session: getIt<SessionCubit>(),
      playback: getIt<PlaybackCubit>(),
      settings: getIt<SettingsCubit>(),
      mediaScope: getIt<MediaScopeCubit>(),
    ),
  );
}
