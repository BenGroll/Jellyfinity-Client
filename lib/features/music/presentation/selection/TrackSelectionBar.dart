import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import 'bulk_playlist_selection.dart';
import 'TrackSelectionCubit.dart';
import 'TrackSelectionState.dart';

/// The "N selected / Cancel / Add to playlist" bar a song list shows above
/// its rows once selection mode is on (v0.7.0).
///
/// One widget reused by every required surface (search results, album
/// tracks, artist songs, Favorites, Downloads, playlist rows, and the
/// Library/Favorites Songs tabs) rather than each screen building its own,
/// so the count and the bulk action read and behave identically everywhere
/// `TrackRow` already does.
///
/// [selectableTracks] must be the screen's currently loaded, currently
/// playable tracks in displayed order — the same list passed to
/// `TrackRow.onSelectToggle` — since it is also what
/// [addSelectedTracksToPlaylist] orders and filters against.
///
/// [showEntryButton] adds a lone "Select" button while selection mode is
/// off, for a screen with nowhere else to put one. It defaults to true; a
/// screen whose `AppScaffold` has an actions row puts a "Select" icon
/// there instead — a fixed app-bar icon costs no extra scroll height,
/// where an inline entry button would push the row list down every time,
/// including for the two- and three-song playlists `PlaylistDetailPage`'s
/// widget tests use, which broke against the default test viewport before
/// this was split out.
class TrackSelectionBar extends StatelessWidget {
  const TrackSelectionBar({
    super.key,
    required this.selectableTracks,
    this.showEntryButton = true,
  });

  final List<Track> selectableTracks;
  final bool showEntryButton;

  @override
  Widget build(BuildContext context) {
    if (selectableTracks.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;

    return BlocBuilder<TrackSelectionCubit, TrackSelectionState>(
      builder: (context, state) {
        final cubit = context.read<TrackSelectionCubit>();

        if (!state.active) {
          if (!showEntryButton) return const SizedBox.shrink();
          return Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: cubit.enter,
              icon: const Icon(Icons.checklist_rounded, size: 18),
              label: const Text('Select'),
            ),
          );
        }

        final selectedCount = selectableTracks
            .where((track) => state.selected.contains(track.id))
            .length;

        return Padding(
          padding: EdgeInsets.symmetric(vertical: t.spacing.xxs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$selectedCount selected',
                  style: t.typography.bodyMedium.copyWith(
                    color: t.colors.textPrimary,
                  ),
                ),
              ),
              TextButton(onPressed: cubit.exit, child: const Text('Cancel')),
              SizedBox(width: t.spacing.xs),
              FilledButton(
                onPressed: selectedCount == 0
                    ? null
                    : () => addSelectedTracksToPlaylist(
                        context,
                        cubit,
                        selectableTracks,
                      ),
                child: const Text('Add to playlist'),
              ),
            ],
          ),
        );
      },
    );
  }
}
