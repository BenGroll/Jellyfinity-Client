import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/downloads/downloads.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/media/media_availability.dart';

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

    test(
      'a completed download the server dropped is "only on this device"',
      () {
        final record = _record(
          'track-1',
          state: DownloadState.completed,
          owner: album,
        ).copyWith(serverGone: true);

        expect(record.isPlayableOffline, isTrue);
        final track = record.toTrack();
        expect(track.availability, MediaAvailability.localOnly);
        expect(track.availability.isOnDevice, isTrue);
        expect(track.availability.isPlayable, isTrue);
      },
    );

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

  group('DownloadCatalog playlist snapshots (v0.2.1)', () {
    final playlist = DownloadOwner.playlist(_id('pl-1'));

    test('a playlist with a snapshot is downloaded, even when empty', () {
      final catalog = DownloadCatalog(
        downloads: const {},
        playlistSnapshots: {_id('pl-1'): const []},
        isLoaded: true,
      );

      expect(catalog.isPlaylistDownloaded(_id('pl-1')), isTrue);
      expect(catalog.isPlaylistDownloaded(_id('pl-2')), isFalse);
    });

    test('returns the downloaded members in the snapshot order', () {
      final catalog = DownloadCatalog(
        downloads: {
          _id('t1'): _record(
            't1',
            state: DownloadState.completed,
            owner: playlist,
          ),
          _id('t2'): _record(
            't2',
            state: DownloadState.completed,
            owner: playlist,
          ),
        },
        playlistSnapshots: {
          _id('pl-1'): [
            (position: 0, trackId: _id('t2')),
            (position: 1, trackId: _id('t1')),
          ],
        },
        isLoaded: true,
      );

      expect(
        catalog.playlistDownloadsInOrder(_id('pl-1')).map((r) => r.id.itemId),
        ['t2', 't1'],
      );
    });

    test('skips a member whose record has gone rather than leaving a hole', () {
      final catalog = DownloadCatalog(
        downloads: {
          _id('t1'): _record(
            't1',
            state: DownloadState.completed,
            owner: playlist,
          ),
        },
        playlistSnapshots: {
          _id('pl-1'): [
            (position: 0, trackId: _id('t1')),
            (position: 1, trackId: _id('gone')),
          ],
        },
        isLoaded: true,
      );

      expect(
        catalog.playlistDownloadsInOrder(_id('pl-1')).map((r) => r.id.itemId),
        ['t1'],
      );
    });
  });

  group('DownloadCatalog management view (v0.2.2)', () {
    final artist = DownloadOwner.artist(_id('ar-1'));

    test('an artist collection aggregates like any other owner', () {
      final catalog = _catalog([
        _record('a', state: DownloadState.completed, owner: artist),
        _record('b', state: DownloadState.failed, owner: artist),
      ]);

      final status = catalog.statusFor(artist);
      expect(status.total, 2);
      expect(status.completed, 1);
      expect(status.failed, 1);
      expect(status.needsAttention, isTrue);
    });

    test('counts waiting-for-network downloads as active, not attention', () {
      final catalog = _catalog([
        _record('a', state: DownloadState.waitingForNetwork, owner: artist),
      ]);

      final status = catalog.statusFor(artist);
      expect(status.waitingForNetwork, 1);
      expect(status.isActive, isTrue);
      expect(status.needsAttention, isFalse);
    });

    test('sums storage from completed files only', () {
      final catalog = _catalog([
        _record(
          'a',
          state: DownloadState.completed,
          owner: artist,
          totalBytes: 3_000_000,
        ),
        _record(
          'b',
          state: DownloadState.completed,
          owner: artist,
          totalBytes: 2_000_000,
        ),
        _record(
          'c',
          state: DownloadState.downloading,
          owner: artist,
          receivedBytes: 500_000,
          totalBytes: 4_000_000,
        ),
      ]);

      expect(catalog.storageInUse, 5_000_000);
      expect(catalog.statusFor(artist).storageInUse, 5_000_000);
    });

    test('lists each album, artist and playlist collection once', () {
      final catalog = DownloadCatalog(
        downloads: {
          _id('t1'): TrackDownload(
            id: _id('t1'),
            title: 't1',
            state: DownloadState.completed,
            owners: {album, artist},
            requestedAt: DateTime.utc(2026),
          ),
          _id('t2'): _record(
            't2',
            state: DownloadState.completed,
            owner: DownloadOwner.track(_id('t2')),
          ),
        },
        playlistSnapshots: {
          _id('pl-1'): [(position: 0, trackId: _id('t1'))],
        },
        isLoaded: true,
      );

      expect(catalog.collectionOwners.toSet(), {
        album,
        artist,
        DownloadOwner.playlist(_id('pl-1')),
      });
      // t2 is only ever wanted by itself — a standalone song, not a
      // collection.
      expect(catalog.standaloneTrackDownloads.map((r) => r.id.itemId), ['t2']);
    });

    test('orders collections by kind and name, not by map order', () {
      // The set is built by walking maps whose iteration order shifts as
      // records change state, so an unsorted answer made the Downloads
      // screen reshuffle its Collections list while a download ran.
      DownloadCatalog catalogOf(Iterable<MapEntry<String, String>> albums) {
        final owners = {
          for (final entry in albums)
            DownloadOwner.album(_id(entry.key)): entry.value,
        };
        return DownloadCatalog(
          downloads: {
            for (final owner in owners.keys)
              _id('t-${owner.id.itemId}'): _record(
                't-${owner.id.itemId}',
                state: DownloadState.completed,
                owner: owner,
              ),
          },
          collections: {
            for (final entry in owners.entries)
              entry.key: DownloadedCollection(
                owner: entry.key,
                name: entry.value,
              ),
          },
          isLoaded: true,
        );
      }

      final pairs = [
        const MapEntry('al-1', 'Zoo'),
        const MapEntry('al-2', 'apple'),
        const MapEntry('al-3', 'Mango'),
      ];
      const expected = ['apple', 'Mango', 'Zoo'];

      names(DownloadCatalog c) => [
        for (final owner in c.collectionOwners) c.collectionName(owner),
      ];

      expect(names(catalogOf(pairs)), expected);
      // The same collections inserted the other way round still read the
      // same way.
      expect(names(catalogOf(pairs.reversed)), expected);
    });

    test('groups collections of a kind together', () {
      final catalog = DownloadCatalog(
        downloads: {
          _id('t1'): _record(
            't1',
            state: DownloadState.completed,
            owner: artist,
          ),
          _id('t2'): _record(
            't2',
            state: DownloadState.completed,
            owner: album,
          ),
        },
        playlistSnapshots: {
          _id('pl-1'): [(position: 0, trackId: _id('t1'))],
        },
        isLoaded: true,
      );

      // Declaration order of DownloadOwnerKind. Which kind leads is
      // arbitrary; that the answer is grouped and the same every rebuild
      // is the point.
      expect(catalog.collectionOwners.map((owner) => owner.kind), [
        DownloadOwnerKind.album,
        DownloadOwnerKind.playlist,
        DownloadOwnerKind.artist,
      ]);
    });
  });

  group('DownloadCatalog collection identity (v0.2.3)', () {
    final playlist = DownloadOwner.playlist(_id('pl-1'));

    test('prefers the stored name over one reconstructed from tracks', () {
      final catalog = DownloadCatalog(
        collections: {
          playlist: DownloadedCollection(owner: playlist, name: 'Roadtrip'),
        },
        isLoaded: true,
      );

      expect(catalog.collectionName(playlist), 'Roadtrip');
      expect(catalog.collectionIdentity(playlist)?.name, 'Roadtrip');
    });

    test('a playlist with no stored identity falls back to the label', () {
      const catalog = DownloadCatalog(isLoaded: true);
      expect(
        catalog.collectionName(playlist, fallback: 'Downloaded playlist'),
        'Downloaded playlist',
      );
    });

    test('a collection with only a stored identity still lists', () {
      final catalog = DownloadCatalog(
        collections: {
          playlist: DownloadedCollection(owner: playlist, name: 'Empty Mix'),
        },
        isLoaded: true,
      );
      expect(catalog.collectionOwners, contains(playlist));
    });
  });
}
