import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media_id.dart';

void main() {
  const id = MediaId(serverId: 'server-1', itemId: 'item-9');

  test('is the pair of server and item, not the item alone', () {
    const sameItemElsewhere = MediaId(serverId: 'server-2', itemId: 'item-9');

    expect(id, const MediaId(serverId: 'server-1', itemId: 'item-9'));
    expect(id, isNot(sameItemElsewhere));
  });

  test('round-trips through its string key', () {
    expect(id.key, 'server-1:item-9');
    expect(MediaId.tryParse(id.key), id);
  });

  test('rejects malformed keys instead of throwing', () {
    expect(MediaId.tryParse('no-separator'), isNull);
    expect(MediaId.tryParse(':orphaned-item'), isNull);
    expect(MediaId.tryParse('orphaned-server:'), isNull);
    expect(MediaId.tryParse(''), isNull);
  });

  test('keeps the whole item id when it contains a separator', () {
    // Defensive: ids are UUIDs today, but a key must never silently lose
    // part of the id it was built from.
    const awkward = MediaId(serverId: 's', itemId: 'a:b');
    expect(MediaId.tryParse(awkward.key), awkward);
  });
}
