import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'service_locator.config.dart';

/// The application's single service locator instance.
///
/// [getIt] is the composition root: every dependency-injectable service
/// in Jellyfinity is registered here, once, at startup, and resolved
/// through constructor injection from this point on. Application code
/// should reach into [getIt] directly only at the composition edges
/// (bootstrap, and widget-tree wiring); everywhere else, dependencies
/// should be passed in via constructors.
final GetIt getIt = GetIt.instance;

/// Registers every `@injectable`/`@singleton`/`@lazySingleton`-annotated
/// class with [getIt], via the generated [GetIt.init] extension.
///
/// Run `dart run build_runner build --delete-conflicting-outputs` after
/// adding or changing an injectable annotation to regenerate
/// `service_locator.config.dart`.
///
/// Values that are constructed from runtime/environment state rather
/// than plain class dependencies (e.g. [AppConfig][1]) are registered
/// directly by [bootstrap] before this runs, rather than via an
/// injectable annotation, so that construction logic stays next to the
/// value it produces rather than living in a DI module.
///
/// [1]: ../../core/config/AppConfig.dart
@InjectableInit()
Future<void> configureDependencies() async => getIt.init();
