import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import 'music_rows.dart';

/// The shape of a music list before its data arrives.
///
/// Deliberately the same geometry as [ArtistRow]/[TrackRow] — same row
/// height, same artwork box, same two lines of text — so the content
/// replaces the skeleton without anything moving. That is the difference
/// between "loading" and "loading, and you can already see what is
/// coming" (`PHILOSOPHY.md` §2).
class MusicListSkeleton extends StatelessWidget {
  const MusicListSkeleton({
    super.key,
    this.itemCount = 10,
    this.circular = false,
  });

  final int itemCount;

  /// Artists are circles, everything else is a rounded square.
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      children: [
        for (var i = 0; i < itemCount; i++)
          SizedBox(
            height: musicRowHeight,
            child: Row(
              children: [
                if (circular)
                  const AppSkeleton.circle(size: rowArtworkSize)
                else
                  AppSkeleton(
                    width: rowArtworkSize,
                    height: rowArtworkSize,
                    borderRadius: t.radii.smBorder,
                  ),
                SizedBox(width: t.spacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(height: 14, width: 120.0 + (i % 4) * 40),
                      SizedBox(height: t.spacing.xs),
                      AppSkeleton(height: 11, width: 80.0 + (i % 3) * 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The shape of the albums grid before its data arrives, laid out on the
/// same delegate as the real grid.
class AlbumGridSkeleton extends StatelessWidget {
  const AlbumGridSkeleton({
    super.key,
    required this.gridDelegate,
    this.itemCount = 9,
  });

  final SliverGridDelegate gridDelegate;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: gridDelegate,
      itemCount: itemCount,
      itemBuilder: (context, index) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppSkeleton(
              height: double.infinity,
              borderRadius: t.radii.smBorder,
            ),
          ),
          SizedBox(height: t.spacing.xs),
          const AppSkeleton(height: 13),
          SizedBox(height: t.spacing.xxs),
          const AppSkeleton(height: 10, width: 70),
        ],
      ),
    );
  }
}

/// The shape of a detail header — artwork, title, credits, actions —
/// while the item itself is loading.
class MediaHeaderSkeleton extends StatelessWidget {
  const MediaHeaderSkeleton({super.key, this.artworkSize = 160});

  final double artworkSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      children: [
        SizedBox(height: t.spacing.md),
        AppSkeleton(
          width: artworkSize,
          height: artworkSize,
          borderRadius: t.radii.mdBorder,
        ),
        SizedBox(height: t.spacing.md),
        const AppSkeleton(width: 200, height: 20),
        SizedBox(height: t.spacing.xs),
        const AppSkeleton(width: 140, height: 13),
        SizedBox(height: t.spacing.lg),
      ],
    );
  }
}
