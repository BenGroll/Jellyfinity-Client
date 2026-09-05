import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/downloads/downloads.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';

import '../../support/music_fakes.dart';

MediaId _id(String item) => mediaId(item);

TrackDownload _record(
  String item, {
  required DownloadState state,
  required DownloadOwner owner,
  int receivedBytes = 0,
  int? totalBytes,
}) => TrackDownload(
  id: _id(item),
  title: item,
  state: state,
  owners: {owner},
  requestedAt: DateTime.utc(2026, 1, 1),
  receivedBytes: receivedBytes,
  totalBytes: totalBytes,
);

DownloadCatalog _catalog(List<TrackDownload> records) => DownloadCatalog(
  downloads: {for (final record in records) record.id: record},
  isLoaded: true,
);

void main() {
  final album = DownloadOwner.album(_id('album-1'));
  final other = DownloadOwner.album(_id('album-2'));

  group('TrackDownload', () {
    test('reports progress as a fraction once the size is known', () {
      final record = _record(
        'track-1',
        state: DownloadState.downloading,
        owner: album,
        receivedBytes: 250,
        totalBytes: 1000,
      );

      expect(record.progress, 0.25);
    });

    test('has no progress fraction while the size is unknown', () {
      final record = _record(
        'track-1',
        state: DownloadState.downloading,
        owner: album,
        receivedBytes: 250,
      );

      // Indeterminate, rather than a percentage nobody measured.
      expect(record.progress, isNull);
    });

    test('a completed download is whole and playable without the server', () {
      final record = _record(
        'track-1',
        state: DownloadState.completed,
        owner: album,
      );

      expect(record.progress, 1);
      expect(record.isPlayableOffline, isTrue);
      expect(record.toTrack().availability.requiresServer, isFalse);
    });

    test('an unfinished download is not yet playable offline', () {
      final record = _record(
        'track-1',
        state: DownloadState.downloading,
        owner: album,
      );

      expect(record.isPlayableOffline, isFalse);
      expect(record.toTrack().availability.isOnDevice, isFalse);
    });

    test('carries enough metadata to rebuild the track it came from', () {
      final track = testTrack('track-1', name: 'So What', albumId: 'album-1');
      final record = TrackDownload.requested(
        track,
        owner: DownloadOwner.track(track.id),
        requestedAt: DateTime.utc(2026),
      ).copyWith(state: DownloadState.completed);

      final rebuilt = record.toTrack();
      expect(rebuilt.id, track.id);
      expect(rebuilt.name, 'So What');
      expect(rebuilt.albumName, track.albumName);
      expect(rebuilt.duration, track.duration);
    });
  });

  group('DownloadCatalog aggregation', () {
    test('a collection nothing was asked for has no status', () {
      expect(_catalog([]).statusFor(album), CollectionDownloadStatus.none);
      expect(_catalog([]).statusFor(album).isEmpty, isTrue);
    });

    test('counts each state separately rather than averaging them', () {
      final catalog = _catalog([
        _record('a', state: DownloadState.completed, owner: album),
        _record('b', state: DownloadState.downloading, owner: album),
        _record('c', state: DownloadState.failed, owner: album),
        _record('d', state: DownloadState.paused, owner: album),
      ]);

      final status = catalog.statusFor(album);
      expect(status.total, 4);
      expect(status.completed, 1);
      expect(status.pending, 1);
      expect(status.failed, 1);
      expect(status.paused, 1);
      expect(status.isComplete, isFalse);
      // A failure is never concealed by the tracks that did finish.
      expect(status.needsAttention, isTrue);
    });

    test('weighs progress by bytes when every size is known', () {
      final catalog = _catalog([
        _record(
          'a',
          state: DownloadState.completed,
          owner: album,
          totalBytes: 900,
        ),
        _record(
          'b',
          state: DownloadState.downloading,
          owner: album,
          receivedBytes: 50,
          totalBytes: 100,
        ),
      ]);

      // 950 of 1000 bytes — not "one of two tracks".
      expect(catalog.statusFor(album).progress, closeTo(0.95, 0.0001));
    });

    test('falls back to track counts when a size is missing', () {
      final catalog = _catalog([
        _record(
          'a',
          state: DownloadState.completed,
          owner: album,
          totalBytes: 900,
        ),
        _record('b', state: DownloadState.queued, owner: album),
      ]);

      expect(catalog.statusFor(album).progress, 0.5);
    });

    test('an album is complete only when every track it asked for is', () {
      final catalog = _catalog([
        _record('a', state: DownloadState.completed, owner: album),
        _record('b', state: DownloadState.completed, owner: album),
      ]);

      final status = catalog.statusFor(album);
      expect(status.isComplete, isTrue);
      expect(status.needsAttention, isFalse);
      expect(status.progress, 1);
    });

    test('one collection does not count another collection\'s tracks', () {
      final catalog = _catalog([
        _record('a', state: DownloadState.completed, owner: album),
        _record('b', state: DownloadState.failed, owner: other),
      ]);

      expect(catalog.statusFor(album).total, 1);
      expect(catalog.statusFor(album).failed, 0);
      expect(catalog.statusFor(other).failed, 1);
    });

    test('a track kept by two collections counts in both', () {
      final shared = TrackDownload(
        id: _id('a'),
        title: 'a',
        state: DownloadState.completed,
        owners: {album, other},
        requestedAt: DateTime.utc(2026),
      );
      final catalog = _catalog([shared]);

      expect(catalog.statusFor(album).completed, 1);
      expect(catalog.statusFor(other).completed, 1);
    });

    test('answers whether one track is on the device', () {
      final catalog = _catalog([
        _record('a', state: DownloadState.completed, owner: album),
        _record('b', state: DownloadState.downloading, owner: album),
      ]);

      expect(catalog.isDownloaded(_id('a')), isTrue);
      expect(catalog.isDownloaded(_id('b')), isFalse);
      expect(catalog.isDownloaded(_id('missing')), isFalse);
      expect(catalog.stateOf(_id('missing')), isNull);
    });
  });
}
