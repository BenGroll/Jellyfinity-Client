import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:injectable/injectable.dart';

import '../../domain/downloads/DownloadStorageProbe.dart';

/// [DownloadStorageProbe] over `disk_space_plus` (v0.2.3).
///
/// Platform-channel work behind a replaceable seam, the same kind of
/// dependency `CONTEXT.md` says a dependency should be and the same shape
/// as `ConnectivityNetworkCondition` (ADR-0022). The plugin reports free
/// space in megabytes as a `double`; anything it cannot answer — an
/// unsupported platform, a channel error — comes back as `null`, which
/// the caller treats as "unknown", not "full".
@LazySingleton(as: DownloadStorageProbe)
class DiskSpaceStorageProbe implements DownloadStorageProbe {
  DiskSpaceStorageProbe({DiskSpacePlus? diskSpace})
    : _diskSpace = diskSpace ?? DiskSpacePlus();

  @factoryMethod
  factory DiskSpaceStorageProbe.create() => DiskSpaceStorageProbe();

  final DiskSpacePlus _diskSpace;

  static const int _bytesPerMegabyte = 1024 * 1024;

  @override
  Future<int?> availableBytes() async {
    try {
      final freeMegabytes = await _diskSpace.getFreeDiskSpace;
      if (freeMegabytes == null || freeMegabytes < 0) return null;
      return (freeMegabytes * _bytesPerMegabyte).round();
    } catch (_) {
      // The probe is advisory: a failure to read free space must never
      // be the reason a download does not start.
      return null;
    }
  }
}
