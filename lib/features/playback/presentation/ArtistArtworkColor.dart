import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/result/result.dart';
import '../../../design/design.dart';
import '../../../domain/media/media.dart';
import '../../../infrastructure/artwork/ArtworkCache.dart';

/// A solid, dark artwork tint, with enough contrast for the player's text.
Color artworkTint(Uint8List rgba) {
  var red = 0.0;
  var green = 0.0;
  var blue = 0.0;
  var weight = 0.0;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    final alpha = rgba[i + 3] / 255;
    red += rgba[i] * alpha;
    green += rgba[i + 1] * alpha;
    blue += rgba[i + 2] * alpha;
    weight += alpha;
  }
  if (weight == 0) return const Color(0xff202028);
  final color = HSLColor.fromColor(
    Color.fromARGB(
      255,
      (red / weight).round(),
      (green / weight).round(),
      (blue / weight).round(),
    ),
  );
  return color.withLightness(color.lightness.clamp(.12, .23)).toColor();
}

Future<Color?> loadArtistArtworkColor(
  MediaId? artistId,
  MediaImage? cover,
) async {
  MediaImage? artistImage;
  if (artistId != null) {
    final result = await getIt<MediaMetadataRepository>().item(artistId);
    if (result case Ok<MediaItem>(value: final Artist artist)) {
      artistImage = artist.image ?? artist.banner;
    }
  }
  for (final image in {artistImage, cover}.whereType<MediaImage>()) {
    try {
      final url = getIt<ArtworkResolver>().imageUrl(image, maxWidth: 400);
      if (url == null) continue;
      final file = await ArtworkCache.instance.getSingleFile(url.toString());
      final codec = await ui.instantiateImageCodec(
        await file.readAsBytes(),
        targetWidth: 24,
        targetHeight: 24,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final bytes = await frame.image.toByteData();
          if (bytes != null) return artworkTint(bytes.buffer.asUint8List());
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // Missing or uncached offline artwork falls back to the cover or theme.
    }
  }
  return null;
}

class ArtistArtworkColor extends StatefulWidget {
  const ArtistArtworkColor({
    super.key,
    required this.artistId,
    required this.cover,
    required this.builder,
    this.load = loadArtistArtworkColor,
  });

  final MediaId? artistId;
  final MediaImage? cover;
  final Widget Function(BuildContext, Color) builder;
  final Future<Color?> Function(MediaId?, MediaImage?) load;

  @override
  State<ArtistArtworkColor> createState() => _ArtistArtworkColorState();
}

class _ArtistArtworkColorState extends State<ArtistArtworkColor> {
  Color? _color;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ArtistArtworkColor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistId != widget.artistId ||
        oldWidget.cover != widget.cover) {
      _color = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final color = await widget.load(widget.artistId, widget.cover);
      if (mounted && generation == _generation) setState(() => _color = color);
    } catch (_) {
      // Artwork is decorative and must never interrupt playback controls.
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _color ?? context.tokens.colors.surface);
}
