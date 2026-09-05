import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/downloads/DownloadsCubit.dart';
import '../../../../domain/downloads/downloads.dart';
import '../../../../domain/media/media.dart';
import '../library/music_collection_cubits.dart';
import '../library/paged_collection_cubit.dart';

/// Reconciles a downloaded album's or artist's tracks against the server
/// the first time its detail screen is opened online (v0.2.3).
///
/// The album/artist counterpart to `PlaylistDetailPage`'s reconcile-on-
/// open: when the track list has loaded from the server (not the cache)
/// and this collection is downloaded, it tells [DownloadsCubit] which
/// track ids the server still lists, so a downloaded track the server has
/// since dropped is marked "only on this device" rather than left looking
/// like a remote failure — and one that reappears loses the mark. It
/// renders [child] unchanged and never deletes anything.
class ReconcileDownloadedCollection extends StatefulWidget {
  const ReconcileDownloadedCollection({
    super.key,
    required this.owner,
    required this.child,
  });

  final DownloadOwner owner;
  final Widget child;

  @override
  State<ReconcileDownloadedCollection> createState() =>
      _ReconcileDownloadedCollectionState();
}

class _ReconcileDownloadedCollectionState
    extends State<ReconcileDownloadedCollection> {
  bool _done = false;

  void _maybeReconcile(PagedCollectionState<Track> tracks) {
    if (_done || !tracks.isReady || tracks.isCached) return;

    final downloads = context.read<DownloadsCubit>();
    if (downloads.state.statusFor(widget.owner).isEmpty) return;

    _done = true;
    downloads.reconcileCollectionPresence(
      widget.owner,
      {for (final track in tracks.items) track.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SongsCubit, PagedCollectionState<Track>>(
      listenWhen: (previous, current) => !_done,
      listener: (context, state) => _maybeReconcile(state),
      child: widget.child,
    );
  }
}
