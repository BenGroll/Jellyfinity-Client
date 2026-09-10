import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/domain/playback/CrossfadeSettings.dart';
import 'package:jellyfinity/domain/playback/NormalizationSettings.dart';
import 'package:jellyfinity/domain/playback/PlaybackSource.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';
import 'package:jellyfinity/infrastructure/downloads/DiskSpaceStorageProbe.dart';
import 'package:jellyfinity/infrastructure/playback/JustAudioPlaybackEngine.dart';

class _NoArtwork implements ArtworkResolver {
  @override
  Uri? imageUrl(MediaImage image, {int? maxWidth, int? maxHeight}) => null;
}

// Silent PCM keeps the smoke test independent of servers and audio fixtures.
Uint8List _wav() {
  const size = 12000 * 2 * 12;
  final bytes = Uint8List(44 + size);
  final data = ByteData.sublistView(bytes);
  void tag(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  tag(0, 'RIFF');
  data.setUint32(4, 36 + size, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 12000, Endian.little);
  data.setUint32(28, 24000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, size, Endian.little);
  return bytes;
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Native playback timed out');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows credentials, disk space, local and HTTP playback', (
    tester,
  ) async {
    if (!Platform.isWindows) return;
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final root = await Directory.systemTemp.createTemp('jellyfinity_native_');
    // Spaces and Unicode exercise Windows path-to-URI conversion.
    final file = await File(
      '${root.path}/Musik ä sample.wav',
    ).writeAsBytes(_wav());
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType('audio', 'wav');
      request.response.contentLength = await file.length();
      await request.response.addStream(file.openRead());
      await request.response.close();
    });
    const credentials = FlutterSecureStorage();
    final key = 'windows-smoke-${DateTime.now().microsecondsSinceEpoch}';
    JustAudioMediaKit.prefetchPlaylist = true;
    JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
    final engine = await AudioService.init(
      builder: () => JustAudioPlaybackEngine(_NoArtwork()),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'io.nachbar.jellyfinity.test',
        androidNotificationChannelName: 'Playback test',
      ),
    );
    var position = Duration.zero;
    var index = 0;
    var status = PlaybackStatus.idle;
    final errors = <Object>[];
    final subscriptions = [
      engine.positionStream.listen((value) => position = value),
      engine.currentIndexStream.listen((value) => index = value ?? 0),
      engine.statusStream.listen((value) => status = value),
      engine.failureStream.listen(errors.add),
    ];
    try {
      await credentials.write(key: key, value: 'test-token');
      expect(await credentials.read(key: key), 'test-token');
      expect(await DiskSpaceStorageProbe().availableBytes(), greaterThan(0));
      final local = PlaybackSource(
        id: const MediaId(serverId: 'test', itemId: 'local'),
        uri: file.uri,
        title: 'Local smoke test',
        duration: const Duration(seconds: 12),
        normalizationGain: -6,
      );
      final remote = PlaybackSource(
        id: const MediaId(serverId: 'test', itemId: 'remote'),
        uri: Uri.parse('http://127.0.0.1:${server.port}/sample.wav'),
        title: 'HTTP smoke test',
        duration: const Duration(seconds: 12),
      );
      await engine.setNormalization(const NormalizationSettings(enabled: true));
      await engine.setSources([local, remote], initialIndex: 0);
      expect(status, isNot(PlaybackStatus.playing));
      unawaited(engine.play());
      await _until(() => position > const Duration(milliseconds: 200));
      await engine.pause();
      await _until(() => status == PlaybackStatus.paused);
      await engine.seek(const Duration(seconds: 2));
      await _until(() => position >= const Duration(seconds: 1));
      // Reorder + duplicate insertion must preserve the selected occurrence.
      await engine.updateSources(
        [remote, local, remote],
        initialIndex: 1,
        initialPosition: const Duration(seconds: 2),
        resumePlaying: true,
      );
      await _until(() => index == 1 && status == PlaybackStatus.playing);
      await engine.skipToIndex(2);
      await _until(
        () => index == 2 && position > const Duration(milliseconds: 100),
      );
      // Exercise both native decks and the handover before natural completion.
      await engine.setCrossfade(
        const CrossfadeSettings(enabled: true, duration: Duration(seconds: 2)),
      );
      await engine.setSources([local, remote], initialIndex: 0);
      unawaited(engine.play());
      await _until(() => index == 0 && position > const Duration(seconds: 1));
      await _until(() => index == 1);
      expect(errors, isEmpty);
    } finally {
      await engine.stop();
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await credentials.delete(key: key);
      await server.close(force: true);
      await root.delete(recursive: true);
    }
  });
}
