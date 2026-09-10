import 'package:flutter/widgets.dart';

/// Marks pages that are composed over the app's shared artwork backdrop.
class ArtworkBackdropScope extends InheritedWidget {
  const ArtworkBackdropScope({
    super.key,
    required this.hasArtwork,
    required super.child,
  });

  final bool hasArtwork;

  static ArtworkBackdropScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ArtworkBackdropScope>();

  @override
  bool updateShouldNotify(ArtworkBackdropScope oldWidget) =>
      hasArtwork != oldWidget.hasArtwork;
}
