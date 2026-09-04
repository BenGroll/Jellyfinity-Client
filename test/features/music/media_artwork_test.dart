import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';

import '../../support/media_fakes.dart';
import '../../support/pump_app.dart';

const _albumImage = MediaImage(
  itemId: MediaId(serverId: 'server-1', itemId: 'album-1'),
  kind: MediaImageKind.primary,
  tag: 'cover-tag',
);

void main() {
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  testWidgets('stands in for an item with no artwork', (tester) async {
    await pumpThemed(
      tester,
      MediaArtwork(
        image: null,
        kind: MediaKind.album,
        size: 56,
        resolver: FakeArtworkResolver(),
      ),
    );

    expect(find.byIcon(Icons.album_rounded), findsOneWidget);
  });

  testWidgets('uses the placeholder that suits the media', (tester) async {
    await pumpThemed(
      tester,
      MediaArtwork(
        image: null,
        kind: MediaKind.artist,
        size: 56,
        shape: ArtworkShape.circle,
        resolver: FakeArtworkResolver(),
      ),
    );

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });

  testWidgets('shows the placeholder when the image has no address', (
    tester,
  ) async {
    // An album cached from another saved server: the metadata is here,
    // the artwork is not addressable, and loading it from the wrong
    // library would be worse than showing nothing.
    await pumpThemed(
      tester,
      MediaArtwork(
        image: _albumImage,
        kind: MediaKind.album,
        size: 56,
        resolver: FakeArtworkResolver(available: false),
      ),
    );

    expect(find.byIcon(Icons.album_rounded), findsOneWidget);
  });

  testWidgets('asks for artwork at the size it will draw', (tester) async {
    final resolver = FakeArtworkResolver();
    Uri? requested;
    var pixelSize = 0;
    MediaArtwork.imageBuilderOverride = (url, size) {
      requested = url;
      pixelSize = size;
      return const SizedBox.shrink();
    };

    await pumpThemed(
      tester,
      MediaArtwork(
        image: _albumImage,
        kind: MediaKind.album,
        size: 64,
        resolver: resolver,
      ),
    );

    final ratio = tester.view.devicePixelRatio;
    expect(pixelSize, (64 * ratio).round());
    expect(resolver.requests.single.maxWidth, pixelSize);
    expect(requested.toString(), contains('tag=cover-tag'));
  });

  testWidgets('reserves its box before anything is loaded', (tester) async {
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();

    await pumpThemed(
      tester,
      MediaArtwork(
        image: _albumImage,
        kind: MediaKind.album,
        size: 72,
        resolver: FakeArtworkResolver(),
      ),
    );

    // The rectangle is the same whether or not the image ever arrives,
    // so a list cannot reflow around it.
    expect(tester.getSize(find.byType(MediaArtwork)), const Size(72, 72));
  });
}
