import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/playback/presentation/ArtistArtworkColor.dart';

import '../../support/music_fakes.dart';
import '../../support/pump_app.dart';

void main() {
  test(
    'artwork tint is opaque, preserves hue and keeps white text readable',
    () {
      final color = artworkTint(Uint8List.fromList([255, 0, 0, 255]));
      expect(color.a, 1);
      expect(color.r, greaterThan(color.b));
      expect(1.05 / (color.computeLuminance() + .05), greaterThan(4.5));
      final transparent = artworkTint(Uint8List.fromList([255, 255, 255, 0]));
      expect(transparent.a, 1);
    },
  );

  testWidgets(
    'artwork follows selection, ignores stale loads and reuses color',
    (tester) async {
      final first = Completer<Color?>();
      final second = Completer<Color?>();
      var calls = 0;
      Future<Color?> load(MediaId? artist, MediaImage? cover) {
        calls++;
        return artist == mediaId('first') ? first.future : second.future;
      }

      Widget player(String artist) => ArtistArtworkColor(
        artistId: mediaId(artist),
        cover: null,
        load: load,
        builder: (_, color) => ColoredBox(key: const Key('tint'), color: color),
      );
      await pumpThemed(tester, player('first'));
      await pumpThemed(tester, player('second'));
      second.complete(Colors.blue);
      await tester.pump();
      first.complete(Colors.red);
      await tester.pump();
      await pumpThemed(tester, player('second'));
      expect(
        tester.widget<ColoredBox>(find.byKey(const Key('tint'))).color,
        Colors.blue,
      );
      expect(calls, 2);
    },
  );
}
