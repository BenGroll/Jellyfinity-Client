import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/favorites/FavoritesRevisionCubit.dart';
import '../../../../domain/media/FavoritesRepository.dart';
import '../../../../domain/media/media_kind.dart';
import '../../../../domain/media/MediaId.dart';

/// The one path a heart button on Artist, Album or Now Playing takes when
/// it is tapped (v0.3.4): write the change to the server, and — on success
/// — tell [FavoritesRevisionCubit] so the Favorites destination and its
/// Home section re-read.
///
/// Returns whether the write succeeded, which [FavoriteButton] uses to
/// keep or revert its optimistic toggle.
Future<bool> applyFavorite(
  BuildContext context,
  MediaId id,
  MediaKind kind, {
  required bool favorite,
}) async {
  final revision = context.read<FavoritesRevisionCubit>();
  final result = await getIt<FavoritesRepository>().setFavorite(
    id,
    favorite: favorite,
    kind: kind,
  );
  if (result.isOk) revision.bump();
  return result.isOk;
}
