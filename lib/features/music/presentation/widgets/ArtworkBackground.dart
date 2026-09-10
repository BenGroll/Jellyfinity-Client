import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import 'MediaArtwork.dart';

/// A bounded, cached wash of artwork color behind a readable detail page.
class ArtworkBackground extends StatelessWidget {
  const ArtworkBackground({
    super.key,
    required this.image,
    required this.child,
  });

  final MediaImage? image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final source = image;
    final url = source == null
        ? null
        : getIt<ArtworkResolver>().imageUrl(source, maxWidth: 400);
    final base = context.tokens.colors.background;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Isolate this page's artwork from any backdrop underneath it, including
        // while the image loads or when no artwork is available.
        Positioned.fill(child: ColoredBox(color: base)),
        if (url != null)
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: ClipRect(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                    child: Transform.scale(
                      scale: 1.25,
                      child: UnframedArtwork(url: url, pixelWidth: 400),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  base.withValues(alpha: .55),
                  base.withValues(alpha: .88),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
