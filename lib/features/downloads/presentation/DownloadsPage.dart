import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/downloads/DownloadsCubit.dart';
import '../../../app/router/route_paths.dart';
import '../../../design/design.dart';
import '../../../domain/downloads/downloads.dart';
import '../../music/presentation/widgets/download_controls.dart';
import '../../music/presentation/widgets/music_rows.dart';
import '../../music/presentation/widgets/music_skeletons.dart';

/// Everything the user has downloaded, in one place (v0.2.2).
///
/// `ROADMAP.md` v0.2.2: "a Downloads screen reachable from normal music
/// navigation. It presents active work, completed collections, failed
/// items, per-item retry/cancel, remove actions, and accurate aggregate
/// storage usage."
///
/// It holds no state of its own — `DownloadsCubit`'s catalog already
/// answers every question the screen asks (what is downloading, what each
/// collection adds up to, how much space it all takes), so this is a pure
/// projection of that one source of truth. The per-item controls are the
/// same `TrackDownloadButton` the track rows elsewhere use, driven off
/// each record rebuilt into a `Track`.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Downloads',
      padded: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      body: BlocBuilder<DownloadsCubit, DownloadCatalog>(
        builder: (context, catalog) {
          if (!catalog.isLoaded) {
            return const MusicListSkeleton(itemCount: 6);
          }

          final nothing =
              catalog.downloads.isEmpty && catalog.playlistSnapshots.isEmpty;
          if (nothing) {
            return const EmptyStateView(
              icon: Icons.download_done_rounded,
              title: 'Nothing downloaded yet',
              message:
                  'Download a song, album, artist or playlist and it plays '
                  'here without a connection. You will see its progress and '
                  'storage use on this screen.',
            );
          }

          final t = context.tokens;
          final unsettled = _unsettled(catalog);
          final collections = catalog.collectionOwners;
          final standalone =
              [
                for (final record in catalog.standaloneTrackDownloads)
                  if (record.state == DownloadState.completed) record,
              ]..sort(
                (a, b) =>
                    a.title.toLowerCase().compareTo(b.title.toLowerCase()),
              );

          return ListView(
            padding: EdgeInsets.only(bottom: t.spacing.xl),
            children: [
              _StorageHeader(catalog: catalog),
              if (unsettled.isNotEmpty) ...[
                _SectionHeader(
                  label: _unsettledLabel(unsettled),
                  icon: Icons.sync_rounded,
                ),
                for (final record in unsettled)
                  TrackRow(
                    track: record.toTrack(),
                    markUnavailable: false,
                    downloadAction: TrackDownloadButton(
                      track: record.toTrack(),
                    ),
                  ),
              ],
              if (collections.isNotEmpty) ...[
                const _SectionHeader(
                  label: 'Collections',
                  icon: Icons.library_music_outlined,
                ),
                for (final owner in collections)
                  _CollectionTile(owner: owner, catalog: catalog),
              ],
              if (standalone.isNotEmpty) ...[
                const _SectionHeader(
                  label: 'Individual songs',
                  icon: Icons.music_note_outlined,
                ),
                for (final record in standalone)
                  TrackRow(
                    track: record.toTrack(),
                    markUnavailable: false,
                    downloadAction: TrackDownloadButton(
                      track: record.toTrack(),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Every record that still has work outstanding or needs the user, most
  /// urgent first: transferring, then queued/waiting, then failed/paused.
  static List<TrackDownload> _unsettled(DownloadCatalog catalog) {
    int rank(DownloadState state) => switch (state) {
      DownloadState.downloading => 0,
      DownloadState.queued => 1,
      DownloadState.waitingForNetwork => 2,
      DownloadState.failed => 3,
      DownloadState.paused => 4,
      DownloadState.completed => 5,
    };
    final records =
        [
          for (final record in catalog.downloads.values)
            if (record.state != DownloadState.completed) record,
        ]..sort((a, b) {
          final byRank = rank(a.state).compareTo(rank(b.state));
          return byRank != 0 ? byRank : a.requestedAt.compareTo(b.requestedAt);
        });
    return records;
  }

  static String _unsettledLabel(List<TrackDownload> records) {
    final failed = records.where((r) => r.state == DownloadState.failed).length;
    final waiting = records
        .where((r) => r.state == DownloadState.waitingForNetwork)
        .length;
    if (failed > 0 && failed == records.length) return 'Needs attention';
    if (waiting > 0 && waiting == records.length) return 'Waiting for Wi-Fi';
    return 'In progress';
  }
}

/// Storage in use and a one-line status across every download.
class _StorageHeader extends StatelessWidget {
  const _StorageHeader({required this.catalog});

  final DownloadCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final overall = catalog.overallStatus;
    final wifiOnlyWaiting = overall.waitingForNetwork > 0;

    return Container(
      margin: EdgeInsets.fromLTRB(
        t.spacing.md,
        t.spacing.md,
        t.spacing.md,
        t.spacing.sm,
      ),
      padding: EdgeInsets.all(t.spacing.md),
      decoration: BoxDecoration(
        color: t.colors.surfaceSunken,
        borderRadius: t.radii.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatDownloadSize(catalog.storageInUse),
            style: t.typography.headlineLarge.copyWith(
              color: t.colors.textPrimary,
            ),
          ),
          SizedBox(height: t.spacing.xxs),
          Text(
            '${overall.completed} ${overall.completed == 1 ? 'song' : 'songs'} '
            'on this device',
            style: t.typography.bodyMedium.copyWith(
              color: t.colors.textSecondary,
            ),
          ),
          if (overall.pending > 0 || overall.failed > 0 || wifiOnlyWaiting) ...[
            SizedBox(height: t.spacing.xs),
            Text(
              describeCollectionDownload(overall),
              style: t.typography.caption.copyWith(
                color: overall.needsAttention
                    ? t.colors.danger
                    : t.colors.textSecondary,
              ),
            ),
          ],
          if (wifiOnlyWaiting) ...[
            SizedBox(height: t.spacing.xxs),
            Text(
              'Waiting downloads resume on their own once you are on Wi-Fi.',
              style: t.typography.caption.copyWith(
                color: t.colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.md,
        t.spacing.md,
        t.spacing.md,
        t.spacing.xs,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: t.colors.textSecondary),
          SizedBox(width: t.spacing.xs),
          Text(
            label,
            style: t.typography.titleMedium.copyWith(
              color: t.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One downloaded album, artist or playlist: its name, what it adds up
/// to, a tap through to its page, and a remove action.
class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.owner, required this.catalog});

  final DownloadOwner owner;
  final DownloadCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final status = catalog.statusFor(owner);
    final downloads = context.read<DownloadsCubit>();

    return ListTile(
      leading: Icon(_icon, color: t.colors.textSecondary),
      title: Text(
        _name(catalog),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.typography.bodyLarge.copyWith(color: t.colors.textPrimary),
      ),
      subtitle: Text(
        '$_kindLabel · ${describeCollectionDownload(status)} · '
        '${formatDownloadSize(status.storageInUse)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.typography.caption.copyWith(
          color: status.needsAttention
              ? t.colors.danger
              : t.colors.textSecondary,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded),
        tooltip: 'Remove download',
        onPressed: () => confirmRemoveDownload(
          context,
          title: 'Remove "${_name(catalog)}"?',
          message:
              'Frees up ${status.completed} downloaded '
              '${status.completed == 1 ? 'track' : 'tracks'}. Songs kept by '
              'another download stay, and nothing changes on your server.',
          onConfirm: () => _remove(downloads),
        ),
      ),
      onTap: () => _open(context),
    );
  }

  void _remove(DownloadsCubit downloads) {
    switch (owner.kind) {
      case DownloadOwnerKind.album:
        downloads.removeAlbum(owner.id);
      case DownloadOwnerKind.artist:
        downloads.removeArtist(owner.id);
      case DownloadOwnerKind.playlist:
        downloads.removePlaylist(owner.id);
      case DownloadOwnerKind.track:
        downloads.removeTrack(owner.id);
    }
  }

  void _open(BuildContext context) {
    final name = switch (owner.kind) {
      DownloadOwnerKind.album => RouteNames.libraryAlbum,
      DownloadOwnerKind.artist => RouteNames.libraryArtist,
      DownloadOwnerKind.playlist => RouteNames.libraryPlaylist,
      DownloadOwnerKind.track => null,
    };
    if (name == null) return;
    context.pushNamed(name, pathParameters: {'id': owner.id.key});
  }

  IconData get _icon => switch (owner.kind) {
    DownloadOwnerKind.album => Icons.album_outlined,
    DownloadOwnerKind.artist => Icons.person_outline_rounded,
    DownloadOwnerKind.playlist => Icons.queue_music_rounded,
    DownloadOwnerKind.track => Icons.music_note_outlined,
  };

  String get _kindLabel => switch (owner.kind) {
    DownloadOwnerKind.album => 'Album',
    DownloadOwnerKind.artist => 'Artist',
    DownloadOwnerKind.playlist => 'Playlist',
    DownloadOwnerKind.track => 'Song',
  };

  /// The collection's name, taken from the denormalized track records
  /// where they carry it (an album name, an artist credit), so the
  /// screen still reads correctly with the server switched off. A
  /// playlist's name is not on the records, so it falls back to a
  /// labelled generic until v0.2.3 gives downloaded collections their
  /// own stored identity.
  String _name(DownloadCatalog catalog) {
    final records = catalog.ownedBy(owner);
    switch (owner.kind) {
      case DownloadOwnerKind.album:
        for (final record in records) {
          if (record.albumName case final name? when name.isNotEmpty) {
            return name;
          }
        }
        return 'Album';
      case DownloadOwnerKind.artist:
        for (final record in records) {
          for (final credit in record.artists) {
            if (credit.id == owner.id && credit.name.isNotEmpty) {
              return credit.name;
            }
          }
        }
        return 'Artist';
      case DownloadOwnerKind.playlist:
        return 'Downloaded playlist';
      case DownloadOwnerKind.track:
        return records.isEmpty ? 'Song' : records.first.title;
    }
  }
}
