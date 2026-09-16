import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:injectable/injectable.dart';

import '../persistence/device_identity_store.dart';
import 'identity/JellyfinClientIdentity.dart';

/// DI wiring for values in the Jellyfin transport layer that are built
/// from construction logic rather than plain constructor injection.
///
/// [JellyfinClientIdentity] needs a stable device id. From v0.0.6 that id
/// is persisted (ADR-0010), so the identity is resolved asynchronously
/// from [DeviceIdentityStore] and `@preResolve`d — `configureDependencies()`
/// reads (or, on first ever launch, generates and writes) the id before
/// the graph is handed out, so every request reports the same device.
@module
abstract class JellyfinTransportModule {
  @preResolve
  @lazySingleton
  Future<JellyfinClientIdentity> clientIdentity(
    DeviceIdentityStore deviceIdentity,
  ) async => JellyfinClientIdentity.forThisApp(
    deviceId: await deviceIdentity.deviceId(),
    deviceName: await _detectedDeviceName(),
  );
}

Future<String> _detectedDeviceName() async {
  final fallback = _platformFallback();
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return _firstNonEmpty([
            _joinNonEmpty([android.manufacturer, android.model]),
          ]) ??
          fallback;
    }
    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return _firstNonEmpty([ios.name, ios.utsname.machine]) ?? fallback;
    }
    if (Platform.isWindows) {
      final windows = await info.windowsInfo;
      return _firstNonEmpty([windows.computerName, Platform.localHostname]) ??
          fallback;
    }
    if (Platform.isMacOS) {
      final macos = await info.macOsInfo;
      return _firstNonEmpty([macos.computerName, Platform.localHostname]) ??
          fallback;
    }
    if (Platform.isLinux) {
      final linux = await info.linuxInfo;
      return _firstNonEmpty([Platform.localHostname, linux.name]) ?? fallback;
    }
  } catch (_) {
    // Device metadata is only a label. A plugin or platform that cannot
    // provide it must never prevent sign-in or connected playback startup.
  }
  return fallback;
}

String? _joinNonEmpty(List<String?> values) {
  final nonEmpty = values
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
  return nonEmpty.isEmpty ? null : nonEmpty.join(' ');
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String _platformFallback() {
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isLinux) return 'Linux';
  return 'Jellyfinity';
}
