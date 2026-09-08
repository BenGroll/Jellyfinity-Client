import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import 'MediaArtwork.dart';

/// A horizontal strip of "you might also like" cards under a detail
/// screen (v0.3.5): related artists on the artist page, similar albums on
/// the album page.
///
/// Takes plain [MediaItem]s so one widget serves both — it draws an
/// artist as a circle and an album as a rounded cover, and reads the
/// "who is this by" line off an [Album]'s credits. Rendered only when
/// [items] is non-empty; the caller keeps the section absent otherwise
/// (ADR-0029).
class RelatedMediaStrip extends StatelessWidget {
  const RelatedMediaStrip({
    super.key,
    required this.title,
    required this.items,
    required this.onOpen,
  });

  final String title;
  final List<MediaItem> items;
  final void Function(MediaItem item) onOpen;

  static const double _cardWidth = 132;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.spacing.md,
            0,
            t.spacing.md,
            t.spacing.xs,
          ),
          child: Text(
            title,
            style: t.typography.titleMedium.copyWith(
              color: t.colors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: _cardWidth + 66,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => SizedBox(width: t.spacing.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return _RelatedCard(
                item: item,
                subtitle: _subtitle(item),
                onTap: () => onOpen(item),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _subtitle(MediaItem item) => switch (item) {
    Album(:final artists) when artists.isNotEmpty => artists.display,
    Album() => 'Album',
    Artist() => 'Artist',
    _ => '',
  };
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({
    required this.item,
    required this.subtitle,
    required this.onTap,
  });

  final MediaItem item;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final circle = item.kind == MediaKind.artist;

    return SizedBox(
      width: RelatedMediaStrip._cardWidth,
      child: InkWell(
        onTap: onTap,
        borderRadius: t.radii.smBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaArtwork(
              image: item.image,
              kind: item.kind,
              size: RelatedMediaStrip._cardWidth,
              shape: circle ? ArtworkShape.circle : ArtworkShape.rounded,
            ),
            SizedBox(height: t.spacing.xs),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.typography.bodyMedium.copyWith(
                color: t.colors.textPrimary,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.caption.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
