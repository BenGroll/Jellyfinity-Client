import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/playlists/PlaylistCurationService.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/result/result.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../library/music_collection_cubits.dart';
import '../library/paged_collection_cubit.dart';
import '../widgets/MediaArtwork.dart';
import '../widgets/media_formatting.dart';
import '../widgets/music_skeletons.dart';
import '../widgets/paged_collection_view.dart';

/// Combines two or more existing playlists into a brand-new one.
///
/// Deliberately always creates a new destination rather than picking an
/// existing playlist to merge into: it means a merge can never overwrite
/// or reorder a playlist the user already has, only add to the pile —
/// undoing a bad merge is "delete the new one", never "try to recall what
/// the target used to contain".
class MergePlaylistsPage extends StatelessWidget {
  const MergePlaylistsPage({super.key, this.playlists});

  final PlaylistsCubit? playlists;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PlaylistsCubit>(
      create: (_) => (playlists ?? getIt<PlaylistsCubit>())..load(),
      child: const _MergePlaylistsView(),
    );
  }
}

class _MergePlaylistsView extends StatefulWidget {
  const _MergePlaylistsView();

  @override
  State<_MergePlaylistsView> createState() => _MergePlaylistsViewState();
}

class _MergePlaylistsViewState extends State<_MergePlaylistsView> {
  final _nameController = TextEditingController();
  final Set<MediaId> _selected = {};
  bool _deleteSources = false;
  bool _merging = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppScaffold(
      padded: false,
      title: 'Merge Playlists',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      body: BlocBuilder<PlaylistsCubit, PagedCollectionState<Playlist>>(
        builder: (context, state) {
          final cubit = context.read<PlaylistsCubit>();
          return PagedCollectionView<Playlist>(
            state: state,
            headerSlivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.md,
                    t.spacing.sm,
                    t.spacing.md,
                    t.spacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pick two or more playlists to combine, in the order '
                        'their songs should end up in.',
                        style: t.typography.bodyMedium.copyWith(
                          color: t.colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: t.spacing.md),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'New playlist name',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Delete originals after merging'),
                        value: _deleteSources,
                        onChanged: _merging
                            ? null
                            : (value) =>
                                  setState(() => _deleteSources = value),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            skeleton: const MusicListSkeleton(),
            emptyTitle: 'No playlists to merge',
            emptyMessage: 'You need at least two playlists first.',
            emptyIcon: Icons.queue_music_outlined,
            onLoadMore: cubit.loadMore,
            onRefresh: cubit.refresh,
            onRetry: cubit.reload,
            onRetryLoadMore: cubit.retryLoadMore,
            itemBuilder: (context, playlist, _) => _SelectablePlaylistRow(
              playlist: playlist,
              selected: _selected.contains(playlist.id),
              onChanged: _merging
                  ? null
                  : (checked) => setState(() {
                      if (checked) {
                        _selected.add(playlist.id);
                      } else {
                        _selected.remove(playlist.id);
                      }
                    }),
            ),
          );
        },
      ),
      bottomBar: Padding(
        padding: EdgeInsets.all(t.spacing.md),
        child: AppButton(
          label: _merging ? 'Merging…' : 'Merge',
          icon: Icons.call_merge_rounded,
          expand: true,
          onPressed: _canMerge ? _merge : null,
        ),
      ),
    );
  }

  bool get _canMerge =>
      !_merging && _selected.length > 1 && _nameController.text.trim().isNotEmpty;

  Future<void> _merge() async {
    setState(() => _merging = true);

    final result = await getIt<PlaylistCurationService>().mergePlaylists(
      name: _nameController.text.trim(),
      sourcePlaylistIds: _selected.toList(growable: false),
      deleteSources: _deleteSources,
    );

    if (!mounted) return;
    switch (result) {
      case Ok<MediaId>(:final value):
        context.pushReplacementNamed(
          RouteNames.libraryPlaylist,
          pathParameters: {'id': value.key},
        );
      case Err<MediaId>(:final failure):
        setState(() => _merging = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _SelectablePlaylistRow extends StatelessWidget {
  const _SelectablePlaylistRow({
    required this.playlist,
    required this.selected,
    required this.onChanged,
  });

  final Playlist playlist;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      onChanged: onChanged == null
          ? null
          : (checked) => onChanged!(checked ?? false),
      secondary: MediaArtwork(
        image: playlist.image,
        kind: MediaKind.playlist,
        size: 40,
      ),
      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatTrackCount(playlist.itemCount) ?? ''),
    );
  }
}
