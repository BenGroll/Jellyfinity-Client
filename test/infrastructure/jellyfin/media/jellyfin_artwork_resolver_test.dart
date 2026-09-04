import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinArtworkResolver.dart';

import '../../../support/FakeSessionContext.dart';

const _image = MediaImage(
  itemId: MediaId(serverId: 'server-1', itemId: 'album-1'),
  kind: MediaImageKind.primary,
  tag: 'tag-1',
);

void main() {
  test('addresses the image on the active server, at the size asked for', () {
    final resolver = JellyfinArtworkResolver(FakeSessionContext());

    final url = resolver.imageUrl(_image, maxWidth: 300)!;

    expect(url.origin, 'https://media.example.com');
    expect(url.path, '/Items/album-1/Images/Primary');
    expect(url.queryParameters['tag'], 'tag-1');
    expect(url.queryParameters['maxWidth'], '300');
    expect(url.queryParameters['quality'], '90');
  });

  test('keeps a base path when the server is behind a reverse proxy', () {
    final resolver = JellyfinArtworkResolver(
      FakeSessionContext(baseUrl: 'https://home.example.com/jellyfin'),
    );

    final url = resolver.imageUrl(_image)!;

    expect(url.path, '/jellyfin/Items/album-1/Images/Primary');
  });

  test('names each image kind the way Jellyfin does', () {
    final resolver = JellyfinArtworkResolver(FakeSessionContext());

    for (final entry in {
      MediaImageKind.primary: 'Primary',
      MediaImageKind.backdrop: 'Backdrop',
      MediaImageKind.logo: 'Logo',
    }.entries) {
      final url = resolver.imageUrl(
        MediaImage(itemId: _image.itemId, kind: entry.key, tag: 'tag-1'),
      )!;
      expect(url.path, endsWith('/Images/${entry.value}'));
    }
  });

  test("refuses to load another server's artwork", () {
    // A cached entity from a second saved server must not have its
    // artwork fetched from the server currently signed in to.
    final resolver = JellyfinArtworkResolver(FakeSessionContext());

    final url = resolver.imageUrl(
      const MediaImage(
        itemId: MediaId(serverId: 'server-2', itemId: 'album-1'),
        kind: MediaImageKind.primary,
        tag: 'tag-1',
      ),
    );

    expect(url, isNull);
  });

  test('has no address while signed out', () {
    final resolver = JellyfinArtworkResolver(FakeSessionContext.signedOut());

    expect(resolver.imageUrl(_image), isNull);
  });
}
