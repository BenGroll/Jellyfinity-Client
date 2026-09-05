/// How much of the library the user wants to see while Jellyfinity is
/// working offline (v0.2.3).
///
/// Only ever consulted when [OfflineMode] reports offline — online, the
/// library is always the full one. Persisted by `SettingsCubit`.
enum OfflineLibraryScope {
  /// The whole cached library stays visible offline, with the tracks and
  /// collections that are actually on the device marked. What Jellyfinity
  /// did before v0.2.3, and the default.
  unlimited,

  /// Offline, the library and search show only what has been downloaded —
  /// nothing that would need the server to play. The "Downloaded" filter,
  /// made automatic while offline.
  limited;

  static const OfflineLibraryScope fallback = OfflineLibraryScope.unlimited;

  static OfflineLibraryScope? tryParse(String? raw) => switch (raw) {
    'unlimited' => OfflineLibraryScope.unlimited,
    'limited' => OfflineLibraryScope.limited,
    _ => null,
  };
}
