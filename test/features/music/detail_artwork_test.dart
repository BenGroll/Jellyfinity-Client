import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/di/service_locator.dart';
import 'package:jellyfinity/design/components/ArtworkBackdropScope.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/music/presentation/detail/AlbumDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/detail/ArtistDetailPage.dart';
import 'package:jellyfinity/features/music/presentation/widgets/ArtworkBackground.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';

import '../../support/music_fakes.dart';
import '../../support/pump_app.dart';

class _ArtworkResolver implements ArtworkResolver {
  @override
  Uri? imageUrl(MediaImage image, {int? maxWidth, int? maxHeight}) =>
      Uri.parse('https://art.example/${image.tag}');
}

void main() {
  setUp(() {
    MediaArtwork.imageBuilderOverride = (_, _) =>
        const ColoredBox(color: Colors.purple);
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  for (final hasBanner in [true, false]) {
    testWidgets(
      'artist uses its ${hasBanner ? 'banner' : 'portrait'} even with a playing-song backdrop',
      (tester) async {
        final portrait = MediaImage(
          itemId: mediaId('artist'),
          kind: MediaImageKind.primary,
          tag: 'portrait',
        );
        final banner = MediaImage(
          itemId: mediaId('artist'),
          kind: MediaImageKind.banner,
          tag: 'banner',
        );
        final music = FakeMusicLibraryRepository()
          ..artistList = [
            Artist(
              id: mediaId('artist'),
              name: 'Artist',
              image: portrait,
              banner: hasBanner ? banner : null,
            ),
          ];
        registerMusicCubits(music: music);
        getIt.registerSingleton<ArtworkResolver>(_ArtworkResolver());
        await pumpThemed(
          tester,
          ArtworkBackdropScope(
            hasArtwork: true,
            child: ArtistDetailPage(artistId: mediaId('artist')),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ArtworkBackground>(find.byType(ArtworkBackground))
              .image,
          hasBanner ? banner : portrait,
        );
        expect(find.byType(ImageFiltered), findsOneWidget);
        expect(tester.widget<AppBar>(find.byType(AppBar)).title, isNull);
        expect(
          tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
          Colors.transparent,
        );
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        if (hasBanner) {
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is UnframedArtwork && widget.url.path == '/banner',
            ),
            findsNWidgets(2),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('album uses its own cover even with a playing-song backdrop', (
    tester,
  ) async {
    final image = MediaImage(
      itemId: mediaId('album'),
      kind: MediaImageKind.primary,
      tag: 'cover',
    );
    final music = FakeMusicLibraryRepository()
      ..albumList = [Album(id: mediaId('album'), name: 'Album', image: image)];
    registerMusicCubits(music: music);
    getIt.registerSingleton<ArtworkResolver>(_ArtworkResolver());
    await pumpThemed(
      tester,
      ArtworkBackdropScope(
        hasArtwork: true,
        child: AlbumDetailPage(albumId: mediaId('album')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ArtworkBackground>(find.byType(ArtworkBackground)).image,
      image,
    );
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).title, isNull);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      Colors.transparent,
    );
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
