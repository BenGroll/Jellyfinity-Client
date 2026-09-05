/// What kind of network the device is on right now (v0.2.2).
///
/// The download system's Wi-Fi-only preference needs exactly one fact
/// about connectivity — is the connection one the user is happy to spend
/// a download on — so this is deliberately three states rather than a
/// full connectivity model. `metered` is "there is a connection, but it
/// is (or is assumed to be) a cellular/paid one"; `unmetered` is Wi-Fi or
/// ethernet; `none` is offline.
enum NetworkState {
  /// Wi-Fi, ethernet, or another connection a download may always use.
  unmetered,

  /// A cellular or otherwise metered connection. A Wi-Fi-only download
  /// waits rather than spends it.
  metered,

  /// No usable connection at all.
  none;

  /// Whether a download is allowed to run now, given [wifiOnly].
  ///
  /// With Wi-Fi-only off, any connection will do (an offline device still
  /// fails the transfer itself, honestly, rather than being pre-empted
  /// here). With it on, only an unmetered connection qualifies.
  bool allowsDownload({required bool wifiOnly}) {
    if (!wifiOnly) return this != NetworkState.none;
    return this == NetworkState.unmetered;
  }
}

/// The seam the download system reads the current [NetworkState] through
/// (v0.2.2).
///
/// A domain contract with a `connectivity_plus`-backed implementation in
/// `lib/infrastructure/downloads/`, the same shape as every other seam in
/// the download system: `DownloadsCubit` owns the *policy* (what a
/// Wi-Fi-only preference means, when a held-back download resumes) and
/// this owns only the *observation*.
///
/// ## A known limitation
///
/// `HttpDownloadEngine` is a foreground engine (ADR-0020), so Wi-Fi-only
/// enforcement is foreground too: a transfer already running when the
/// device drops to cellular is not interrupted mid-file, and a request
/// made while offline is only re-evaluated when connectivity next
/// changes or the app is reopened. This is disclosed in the UI and in
/// ADR-0022; a future OS background-transfer engine would let the policy
/// be enforced continuously.
abstract class NetworkCondition {
  /// The network the device is on right now.
  Future<NetworkState> current();

  /// Fires whenever the network type changes, so a held-back download can
  /// be picked up as soon as Wi-Fi returns without the user reopening the
  /// app.
  Stream<NetworkState> changes();
}
