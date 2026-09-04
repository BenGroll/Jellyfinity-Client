import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/artist.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';

void main() {
  const known = ArtistRef(
    name: 'Miles Davis',
    id: MediaId(serverId: 's1', itemId: 'a1'),
  );
  const credited = ArtistRef(name: 'John Coltrane');

  test('a credit without an item is displayable but not navigable', () {
    expect(credited.isNavigable, isFalse);
    expect(known.isNavigable, isTrue);
  });

  test('joins credits for display', () {
    expect([known, credited].display, 'Miles Davis, John Coltrane');
    expect(<ArtistRef>[].display, isEmpty);
  });

  test('exposes the primary credit, if any', () {
    expect([known, credited].primary, known);
    expect(<ArtistRef>[].primary, isNull);
  });
}
