import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/logging/logger.dart';
import 'json_store.dart';

/// DI wiring for the interim JSON persistence (v0.0.5).
///
/// [JsonStore] needs a directory resolved from `path_provider`, which is
/// an async platform call — so it is provided here rather than by a class
/// annotation. The directory is resolved lazily on first use (see
/// [FileJsonStore]); constructing the store hits no platform channel,
/// which keeps `configureDependencies()` usable in plain unit tests.
///
/// v0.0.6 removes this module along with the JSON store.
@module
abstract class PersistenceModule {
  @lazySingleton
  JsonStore jsonStore(Logger logger) =>
      FileJsonStore(getApplicationSupportDirectory, logger);
}
