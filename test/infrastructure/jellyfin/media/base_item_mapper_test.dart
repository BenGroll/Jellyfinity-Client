import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/base_item_dto.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/BaseItemMapper.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/ItemsResponseDto.dart';

const _mapper = BaseItemMapper('server-1');

BaseItemDto _dto(Map<String, dynamic> json) => BaseItemDto.fromJson(json);

/// One minute in Jellyfin's 100-nanosecond ticks.
const int _minuteInTicks = 600000000;

void main() {
  group('identity', () {
    test('stamps every entity with the server it came from', () {
      final album = _mapper.toAlbum(
        _dto({'Id': 'album-1', 'Name': 'Kind of Blue', 'Type': 'MusicAlbum'}),
      )!;

      expect(album.id, const MediaId(serverId: 'server-1', itemId: 'album-1'));
    });

    test('rejects an item with no id or no name', () {
      expect(_mapper.toAlbum(_dto({'Name': 'No id'})), isNull);
      expect(_mapper.toAlbum(_dto({'Id': 'album-1'})), isNull);
      expect(_mapper.toAlbum(_dto({'Id': 'album-1', 'Name': '   '})), isNull);
      expect(_mapper.toAlbum(_dto({'Id': '', 'Name': 'Empty id'})), isNull);
    });
  });

  group('type discrimination', () {
    test('maps each modelled Jellyfin type to its entity', () {
      final types = {
        'MusicArtist': MediaKind.artist,
        'MusicAlbum': MediaKind.album,
        'Audio': MediaKind.track,
        'Playlist': MediaKind.playlist,
        'Movie': MediaKind.movie,
        'Series': MediaKind.series,
        'Season': MediaKind.season,
        'Episode': MediaKind.episode,
      };

      for (final entry in types.entries) {
        final item = _mapper.toMediaItem(
          _dto({'Id': 'x', 'Name': 'Thing', 'Type': entry.key}),
        );
        expect(item?.kind, entry.value, reason: 'for ${entry.key}');
      }
    });

    test('will not map an item of the wrong type', () {
      // A playlist can hold anything; a film in one must not come back
      // dressed as a song.
      final film = _dto({'Id': 'm1', 'Name': 'Interstellar', 'Type': 'Movie'});

      expect(_mapper.toTrack(film), isNull);
      expect(_mapper.toAlbum(film), isNull);
      expect(_mapper.toMovie(film), isNotNull);
    });

    test('ignores types Jellyfinity does not model', () {
      expect(
        _mapper.toMediaItem(
          _dto({'Id': 'x', 'Name': 'Some Person', 'Type': 'Person'}),
        ),
        isNull,
      );
      expect(_mapper.toMediaItem(_dto({'Id': 'x', 'Name': 'No type'})), isNull);
    });
  });

  group('album', () {
    test('maps the fields an album card shows', () {
      final album = _mapper.toAlbum(
        _dto({
          'Id': 'album-1',
          'Name': 'Kind of Blue',
          'Type': 'MusicAlbum',
          'ProductionYear': 1959,
          'ChildCount': 5,
          'RunTimeTicks': 45 * _minuteInTicks,
          'AlbumArtists': [
            {'Id': 'artist-1', 'Name': 'Miles Davis'},
          ],
          'ImageTags': {'Primary': 'tag-1'},
          'PrimaryImageAspectRatio': 1.0,
        }),
      )!;

      expect(album.name, 'Kind of Blue');
      expect(album.productionYear, 1959);
      expect(album.trackCount, 5);
      expect(album.duration, const Duration(minutes: 45));
      expect(album.artists.single.name, 'Miles Davis');
      expect(
        album.artists.single.id,
        const MediaId(serverId: 'server-1', itemId: 'artist-1'),
      );
      expect(album.image!.tag, 'tag-1');
      expect(album.image!.aspectRatio, 1.0);
    });

    test('leaves unreported details null rather than inventing zeroes', () {
      final album = _mapper.toAlbum(
        _dto({'Id': 'album-1', 'Name': 'Unscanned', 'Type': 'MusicAlbum'}),
      )!;

      expect(album.productionYear, isNull);
      expect(album.trackCount, isNull);
      expect(album.duration, isNull);
      expect(album.image, isNull);
      expect(album.artists, isEmpty);
    });
  });

  group('track', () {
    test('maps disc and track position, album and running time', () {
      final track = _mapper.toTrack(
        _dto({
          'Id': 'track-1',
          'Name': 'So What',
          'Type': 'Audio',
          'IndexNumber': 1,
          'ParentIndexNumber': 2,
          'RunTimeTicks': 9 * _minuteInTicks,
          'AlbumId': 'album-1',
          'Album': 'Kind of Blue',
        }),
      )!;

      expect(track.trackNumber, 1);
      expect(track.discNumber, 2);
      expect(track.duration, const Duration(minutes: 9));
      expect(track.albumName, 'Kind of Blue');
      expect(
        track.albumId,
        const MediaId(serverId: 'server-1', itemId: 'album-1'),
      );
    });

    test('falls back to its album cover when it has no artwork', () {
      final track = _mapper.toTrack(
        _dto({
          'Id': 'track-1',
          'Name': 'So What',
          'Type': 'Audio',
          'AlbumId': 'album-1',
          'AlbumPrimaryImageTag': 'album-tag',
        }),
      )!;

      // The image belongs to the album, so it is cached once for the
      // whole track list rather than once per song.
      expect(
        track.image!.itemId,
        const MediaId(serverId: 'server-1', itemId: 'album-1'),
      );
      expect(track.image!.tag, 'album-tag');
    });

    test('prefers its own artwork over its album cover', () {
      final track = _mapper.toTrack(
        _dto({
          'Id': 'track-1',
          'Name': 'So What',
          'Type': 'Audio',
          'ImageTags': {'Primary': 'own-tag'},
          'AlbumId': 'album-1',
          'AlbumPrimaryImageTag': 'album-tag',
        }),
      )!;

      expect(track.image!.tag, 'own-tag');
      expect(
        track.image!.itemId,
        const MediaId(serverId: 'server-1', itemId: 'track-1'),
      );
    });

    test('prefers performing artists over album artists', () {
      final track = _mapper.toTrack(
        _dto({
          'Id': 'track-1',
          'Name': 'Blue in Green',
          'Type': 'Audio',
          'ArtistItems': [
            {'Id': 'artist-2', 'Name': 'Bill Evans'},
          ],
          'AlbumArtists': [
            {'Id': 'artist-1', 'Name': 'Miles Davis'},
          ],
        }),
      )!;

      expect(track.artists.single.name, 'Bill Evans');
    });

    test('keeps credits the server gave only as names', () {
      final track = _mapper.toTrack(
        _dto({
          'Id': 'track-1',
          'Name': 'Feature',
          'Type': 'Audio',
          'Artists': ['Guest Vocalist'],
        }),
      )!;

      final credit = track.artists.single;
      expect(credit.name, 'Guest Vocalist');
      expect(credit.isNavigable, isFalse);
    });
  });

  group('video', () {
    test('maps an episode with its show, season and position', () {
      final episode = _mapper.toEpisode(
        _dto({
          'Id': 'ep-1',
          'Name': 'Pilot',
          'Type': 'Episode',
          'SeriesId': 'show-1',
          'SeriesName': 'A Show',
          'SeasonId': 'season-1',
          'ParentIndexNumber': 1,
          'IndexNumber': 4,
          'RunTimeTicks': 42 * _minuteInTicks,
          'SeriesPrimaryImageTag': 'show-tag',
        }),
      )!;

      expect(episode.seriesName, 'A Show');
      expect(episode.seasonNumber, 1);
      expect(episode.episodeNumber, 4);
      expect(episode.duration, const Duration(minutes: 42));
      expect(
        episode.image!.itemId,
        const MediaId(serverId: 'server-1', itemId: 'show-1'),
      );
    });

    test('marks an episode with no file as unavailable', () {
      final episode = _mapper.toEpisode(
        _dto({
          'Id': 'ep-2',
          'Name': 'Missing',
          'Type': 'Episode',
          'LocationType': 'Virtual',
        }),
      )!;

      expect(episode.availability, MediaAvailability.remoteUnavailable);
      expect(episode.availability.isPlayable, isFalse);
    });

    test('maps a resume position', () {
      final movie = _mapper.toMovie(
        _dto({
          'Id': 'movie-1',
          'Name': 'Interstellar',
          'Type': 'Movie',
          'RunTimeTicks': 169 * _minuteInTicks,
          'UserData': {
            'PlaybackPositionTicks': 30 * _minuteInTicks,
            'Played': false,
            'LastPlayedDate': '2026-09-01T20:15:00.0000000Z',
          },
        }),
      )!;

      expect(movie.progress.position, const Duration(minutes: 30));
      expect(movie.progress.isResumable, isTrue);
      expect(movie.progress.lastPlayedAt, isNotNull);
      expect(movie.progress.fractionOf(movie.duration!), closeTo(0.177, 0.001));
    });

    test('treats absent user data as never played', () {
      final movie = _mapper.toMovie(
        _dto({'Id': 'movie-1', 'Name': 'Unwatched', 'Type': 'Movie'}),
      )!;

      expect(movie.progress, PlaybackProgress.none);
    });
  });

  group('pages', () {
    ItemsResponseDto response(List<Map<String, dynamic>> items, {int? total}) {
      return ItemsResponseDto.fromJson({
        'Items': items,
        'TotalRecordCount': total ?? items.length,
        'StartIndex': 0,
      });
    }

    test('carries the collection total so browsing can page', () {
      final page = _mapper.toPage(
        response([
          {'Id': 'a1', 'Name': 'One', 'Type': 'MusicAlbum'},
        ], total: 130000),
        request: const PageRequest.first(),
        map: _mapper.toAlbum,
      );

      expect(page.items.single.name, 'One');
      expect(page.totalCount, 130000);
      expect(page.hasMore, isTrue);
    });

    test('records unusable rows instead of failing the window', () {
      final page = _mapper.toPage(
        response([
          {'Id': 'a1', 'Name': 'Good', 'Type': 'MusicAlbum'},
          {'Id': 'a2', 'Type': 'MusicAlbum'},
          {'Id': 'a3', 'Name': 'Also good', 'Type': 'MusicAlbum'},
        ]),
        request: const PageRequest.first(),
        map: _mapper.toAlbum,
      );

      expect(page.items.map((album) => album.name), ['Good', 'Also good']);
      expect(page.unavailable.single.id, 'a2');
      expect(page.consumed, 3);
    });

    test('survives a response with no items at all', () {
      final page = _mapper.toPage(
        ItemsResponseDto.fromJson(const {}),
        request: const PageRequest.first(),
        map: _mapper.toAlbum,
      );

      expect(page.isEmpty, isTrue);
      expect(page.hasMore, isFalse);
    });

    test('stops paging when the server omits the total', () {
      final page = _mapper.toPage(
        ItemsResponseDto.fromJson({
          'Items': [
            {'Id': 'a1', 'Name': 'One', 'Type': 'MusicAlbum'},
          ],
        }),
        request: const PageRequest(startIndex: 100, limit: 100),
        map: _mapper.toAlbum,
      );

      expect(page.startIndex, 100);
      expect(page.totalCount, 101);
      expect(page.hasMore, isFalse);
    });
  });

  group('toTrackSourceInfo (ADR-0015)', () {
    test('reads the first media source and its audio stream', () {
      final track = _dto({
        'Id': 't1',
        'Name': 'A Song',
        'Type': 'Audio',
        'MediaSources': [
          {
            'Container': 'flac',
            'Bitrate': 1000000,
            'MediaStreams': [
              {
                'Type': 'Audio',
                'Codec': 'flac',
                'BitRate': 995000,
                'SampleRate': 44100,
                'BitDepth': 16,
                'Channels': 2,
              },
            ],
          },
        ],
      });

      final info = _mapper.toTrackSourceInfo(track)!;

      expect(info.container, 'flac');
      expect(info.codec, 'flac');
      expect(info.bitrateBps, 995000);
      expect(info.sampleRateHz, 44100);
      expect(info.bitDepth, 16);
      expect(info.channels, 2);
    });

    test('falls back to the source-level bitrate with no audio bitrate', () {
      final track = _dto({
        'Id': 't1',
        'Name': 'A Song',
        'Type': 'Audio',
        'MediaSources': [
          {
            'Container': 'mp3',
            'Bitrate': 320000,
            'MediaStreams': [
              {'Type': 'Audio', 'Codec': 'mp3'},
            ],
          },
        ],
      });

      final info = _mapper.toTrackSourceInfo(track)!;

      expect(info.bitrateBps, 320000);
    });

    test('ignores a non-audio stream and finds the audio one', () {
      final track = _dto({
        'Id': 't1',
        'Name': 'A Song',
        'Type': 'Audio',
        'MediaSources': [
          {
            'Container': 'mkv',
            'MediaStreams': [
              {'Type': 'Video', 'Codec': 'h264'},
              {'Type': 'Audio', 'Codec': 'aac', 'BitRate': 192000},
            ],
          },
        ],
      });

      final info = _mapper.toTrackSourceInfo(track)!;

      expect(info.codec, 'aac');
      expect(info.bitrateBps, 192000);
    });

    test('is null with no media sources at all', () {
      final track = _dto({'Id': 't1', 'Name': 'A Song', 'Type': 'Audio'});

      expect(_mapper.toTrackSourceInfo(track), isNull);
    });

    test('will not map an item of the wrong type', () {
      final album = _dto({
        'Id': 'a1',
        'Name': 'An Album',
        'Type': 'MusicAlbum',
        'MediaSources': [
          {'Container': 'flac'},
        ],
      });

      expect(_mapper.toTrackSourceInfo(album), isNull);
    });
  });
}
