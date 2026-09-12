import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/service_locator.dart';
import '../../../app/playback/PlaybackCubit.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/media.dart';

/// Home's "Play something you'll like" mix (v0.4.5) — a queue built from
/// the signed-in profile's own favorites, honestly falling back to a
/// genuinely random mix when there is not enough favorites signal to
/// build one from.
///
/// A free function over `getIt<MusicLibraryRepository>()`, the same
/// one-shot-action shape `explore_actions.dart` documents: nothing here
/// is state to hold between calls, and the button that triggers it owns
/// its own "building your mix" spinner.
///
/// ## What "you'll like" means
///
/// `PHILOSOPHY.md`/`OUTLOOK.md` §13 rule out an external recommendation
/// service or a tracking backend, so this stays grounded in exactly what
/// the profile has already told Jellyfinity, in order:
///
/// 1. Favorited tracks, directly.
/// 2. A sample from each of a handful of favorited albums.
/// 3. A sample from each of a handful of favorited artists.
///
/// If that is not enough to fill the mix — including a profile with no
/// favorites at all — [MusicLibraryRepository.randomTracks] tops it up.
/// The snackbar after playback starts always says which it was: built
/// entirely from favorites, favorites topped up with a random sample, or
/// (nothing favorited yet) a random mix outright. It never claims more
/// personalization than it actually used.
///
/// Every read this composes already has its own offline story
/// (favorites are cached per profile, ADR-0028; `randomTracks` degrades
/// to downloads while offline, ADR-0034) so the mix degrades along with
/// them without any special-casing here.
Future<void> playForYouMix(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final playback = context.read<PlaybackCubit>();
  final music = getIt<MusicLibraryRepository>();

  final seen = <MediaId>{};
  final fromFavorites = <Track>[];
  void addUnseen(Iterable<Track> tracks) {
    for (final track in tracks) {
      if (seen.add(track.id)) fromFavorites.add(track);
    }
  }

  final favoriteTracks = await music.favoriteTracks(
    page: const PageRequest(limit: _mixSize),
  );
  if (favoriteTracks case Ok<Page<Track>>(:final value)) {
    addUnseen(value.items);
  }

  if (fromFavorites.length < _mixSize) {
    final favoriteAlbums = await music.favoriteAlbums(
      page: const PageRequest(limit: _sourceScanLimit),
    );
    if (favoriteAlbums case Ok<Page<Album>>(:final value)) {
      for (final album in value.items) {
        if (fromFavorites.length >= _mixSize) break;
        final tracks = await music.tracks(
          albumId: album.id,
          page: const PageRequest(limit: _perAlbumSample),
        );
        if (tracks case Ok<Page<Track>>(value: final page)) {
          addUnseen(page.items);
        }
      }
    }
  }

  if (fromFavorites.length < _mixSize) {
    final favoriteArtists = await music.favoriteArtists(
      page: const PageRequest(limit: _sourceScanLimit),
    );
    if (favoriteArtists case Ok<Page<Artist>>(:final value)) {
      for (final artist in value.items) {
        if (fromFavorites.length >= _mixSize) break;
        final tracks = await music.tracks(
          artistId: artist.id,
          page: const PageRequest(limit: _perArtistSample),
        );
        if (tracks case Ok<Page<Track>>(value: final page)) {
          addUnseen(page.items);
        }
      }
    }
  }

  fromFavorites.shuffle();
  final favoriteCount = fromFavorites.length;
  final mix = fromFavorites.take(_mixSize).toList();

  if (mix.length < _mixSize) {
    final topUp = await music.randomTracks(limit: _mixSize - mix.length);
    if (topUp case Ok<List<Track>>(:final value)) {
      for (final track in value) {
        if (seen.add(track.id)) mix.add(track);
      }
    }
  }

  if (!context.mounted) return;

  if (mix.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Nothing to mix yet — your library needs a few songs in it first.',
        ),
      ),
    );
    return;
  }

  await playback.playShuffled(mix);
  if (!context.mounted) return;

  final message = favoriteCount == 0
      ? "You don't have any favorites yet, so this is a random mix from "
            'your library.'
      : mix.length > favoriteCount
      ? 'A mix from your favorites, topped up with a bit of your library.'
      : 'A mix from your favorites.';
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

/// How many tracks a mix holds.
const int _mixSize = 30;

/// How many favorite albums/artists to sample from before falling back
/// to a random top-up — a handful, not every favorite the profile has.
const int _sourceScanLimit = 5;

/// How many of one favorite album's tracks count as its sample —
/// generous, since almost every real album fits in one page at this
/// size.
const int _perAlbumSample = 20;

/// How many of one favorite artist's tracks count as its sample — a
/// bounded taste of a discography that could run to hundreds of songs,
/// not an attempt to represent all of it.
const int _perArtistSample = 10;
