/// How much room is left on the device for downloads (v0.2.3).
///
/// `ROADMAP.md` v0.2.3 asks for "a storage-warning threshold before a
/// request cannot complete". This is the one fact that needs — is there
/// enough space left that a download is worth starting — behind a
/// replaceable seam, the same shape as `NetworkCondition`: `DownloadsCubit`
/// owns the *policy* (the threshold, what a warning says) and this owns
/// only the *measurement*.
///
/// [availableBytes] is `null` when the platform will not say. The warning
/// then simply does not fire, rather than blocking a download on a number
/// nobody has — the same "don't pre-empt on a guess" stance the Wi-Fi-only
/// preference takes when it is off.
abstract class DownloadStorageProbe {
  /// Bytes free on the volume downloads are written to, or `null` when
  /// that cannot be determined on this platform.
  Future<int?> availableBytes();
}

/// The device is running low on room for downloads (v0.2.3).
///
/// Returned by `DownloadsCubit.storageWarning` when free space is known
/// and under the threshold, so a screen can warn a listener *before*
/// they start a large download rather than after a track fails to write.
/// Purely advisory — the roadmap adds no automatic cleanup in this
/// release, so a warned download still proceeds if the user asks.
class DownloadStorageWarning {
  const DownloadStorageWarning({
    required this.availableBytes,
    required this.thresholdBytes,
  });

  /// Bytes free on the device right now.
  final int availableBytes;

  /// The level at or below which this warning fires.
  final int thresholdBytes;
}
