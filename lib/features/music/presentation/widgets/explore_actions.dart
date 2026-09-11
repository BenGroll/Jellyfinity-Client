import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/result/result.dart';
import '../../../../domain/media/media.dart';

/// "Surprise me" — Library exploration's random pick (v0.4.4, ADR-0034).
///
/// Free functions over `getIt<MusicLibraryRepository>()`, the same shape
/// [playlist_actions.dart] documents for the favorite toggle and playlist
/// curation: a one-shot read with nowhere to keep state between calls —
/// the button that triggered it already owns its own "picking" spinner.
/// A successful pick opens the item's detail page directly; a failure
/// (an empty scope, or a server that could not be reached) surfaces as a
/// snackbar rather than navigating nowhere.
Future<void> pickRandomAlbum(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await getIt<MusicLibraryRepository>().randomAlbum();
  if (!context.mounted) return;

  switch (result) {
    case Ok<Album>(:final value):
      context.pushNamed(
        RouteNames.libraryAlbum,
        pathParameters: {'id': value.id.key},
      );
    case Err<Album>(:final failure):
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

Future<void> pickRandomArtist(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await getIt<MusicLibraryRepository>().randomArtist();
  if (!context.mounted) return;

  switch (result) {
    case Ok<Artist>(:final value):
      context.pushNamed(
        RouteNames.libraryArtist,
        pathParameters: {'id': value.id.key},
      );
    case Err<Artist>(:final failure):
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
  }
}
