import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/artist.dart';
import 'package:jellyfinity/domain/media/media_availability.dart';
import 'package:jellyfinity/infrastructure/downloads/DownloadsLibrarySource.dart';

import '../../support/download_fakes.dart';
import '../../support/music_fakes.dart';

void main() {
  late InMemoryDownloadStore store;
  late DownloadsLibrarySource source;

  setUp(() {
    store = InMemoryDownloadStore();
    source = DownloadsLibrarySource(store);
  });

  test(
    'lists downloaded albums as ordinary album pages, marked cached',
    () async {
      final owner = DownloadOwner.album(mediaId('al-1'));
      await store.saveCollection(
        DownloadedCollection(owner: owner, name: 'Blue Train'),
      );

      final page = (await source.albums()).valueOrNull!;

      expect(page.items.single.name, 'Blue Train');
      expect(page.items.single.availability, MediaAvailability.localAndRemote);
      expect(page.isCached, isTrue);
    },
  );

  test('lists completed track downloads and honours the search term', () async {
    store.records[mediaId('t1')] = downloadRecord(
      mediaId('t1'),
      title: 'So What',
      state: DownloadState.completed,
    );
    store.records[mediaId('t2')] = downloadRecord(
      mediaId('t2'),
      title: 'Blue in Green',
      state: DownloadState.completed,
    );

    final all = (await source.tracks()).valueOrNull!;
    expect(
      all.items.map((t) => t.name),
      containsAll(['So What', 'Blue in Green']),
    );

    final filtered = (await source.tracks(searchTerm: 'blue')).valueOrNull!;
    expect(filtered.items.single.name, 'Blue in Green');
  });

  test(
    'a server-dropped track download reads as "only on this device"',
    () async {
      store.records[mediaId('t1')] = downloadRecord(
        mediaId('t1'),
        title: 'So What',
        state: DownloadState.completed,
      ).copyWith(serverGone: true);

      final page = (await source.tracks()).valueOrNull!;
      expect(page.items.single.availability, MediaAvailability.localOnly);
    },
  );

  test(
    'an album is browsable from one downloaded track of it (v0.2.3)',
    () async {
      store.records[mediaId('t1')] = TrackDownload(
        id: mediaId('t1'),
        title: 'So What',
        state: DownloadState.completed,
        owners: {DownloadOwner.track(mediaId('t1'))},
        requestedAt: DateTime.utc(2026),
        albumId: mediaId('al-9'),
        albumName: 'Kind of Blue',
      );

      final albums = (await source.albums()).valueOrNull!;
      expect(albums.items.single.name, 'Kind of Blue');
      expect(albums.items.single.id, mediaId('al-9'));
    },
  );

  test('an artist is browsable from one downloaded track (v0.2.3)', () async {
    store.records[mediaId('t1')] = TrackDownload(
      id: mediaId('t1'),
      title: 'So What',
      state: DownloadState.completed,
      owners: {DownloadOwner.track(mediaId('t1'))},
      requestedAt: DateTime.utc(2026),
      artists: [ArtistRef(name: 'Miles Davis', id: mediaId('ar-1'))],
    );

    final artists = (await source.artists()).valueOrNull!;
    expect(artists.items.single.name, 'Miles Davis');

    // No hit for an artist that has nothing downloaded.
    final filtered = (await source.artists(
      searchTerm: 'coltrane',
    )).valueOrNull!;
    expect(filtered.items, isEmpty);
  });

  test(
    'an explicit artist download and a loose track are one row, not two',
    () async {
      final owner = DownloadOwner.artist(mediaId('ar-1'));
      await store.saveCollection(
        DownloadedCollection(owner: owner, name: 'Miles Davis'),
      );
      store.records[mediaId('t1')] = TrackDownload(
        id: mediaId('t1'),
        title: 'So What',
        state: DownloadState.completed,
        owners: {DownloadOwner.track(mediaId('t1'))},
        requestedAt: DateTime.utc(2026),
        artists: [ArtistRef(name: 'Miles Davis', id: mediaId('ar-1'))],
      );

      final artists = (await source.artists()).valueOrNull!;
      expect(artists.items, hasLength(1));
    },
  );

  test(
    'a still-downloading track does not make its album browsable yet',
    () async {
      store.records[mediaId('t1')] = TrackDownload(
        id: mediaId('t1'),
        title: 'So What',
        state: DownloadState.downloading,
        owners: {DownloadOwner.track(mediaId('t1'))},
        requestedAt: DateTime.utc(2026),
        albumId: mediaId('al-9'),
        albumName: 'Kind of Blue',
      );

      final albums = (await source.albums()).valueOrNull!;
      expect(albums.items, isEmpty);
    },
  );
}
