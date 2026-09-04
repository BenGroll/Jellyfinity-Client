import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/jellyfin_media_metadata_repository.dart';

import '../../../support/fake_dio_adapter.dart';
import '../../../support/media_fakes.dart';

const _id = MediaId(serverId: 'server-1', itemId: 'item-1');

JellyfinMediaMetadataRepository _repository(FakeDioAdapter adapter) =>
    JellyfinMediaMetadataRepository(testMediaApi(adapter));

FakeDioAdapter _answering(Map<String, dynamic> item) =>
    FakeDioAdapter((_) async => jsonResponseBody(itemsResponse([item])));

void main() {
  test('resolves an id to whichever kind of item it turns out to be', () async {
    final cases = {
      'MusicAlbum': MediaKind.album,
      'Audio': MediaKind.track,
      'Episode': MediaKind.episode,
    };

    for (final entry in cases.entries) {
      final result = await _repository(
        _answering({'Id': 'item-1', 'Name': 'Thing', 'Type': entry.key}),
      ).item(_id);

      expect(result.valueOrNull!.kind, entry.value, reason: 'for ${entry.key}');
      expect(result.valueOrNull!.id, _id);
    }
  });

  test('treats a kind Jellyfinity does not present as a dead link', () async {
    final result = await _repository(
      _answering({'Id': 'item-1', 'Name': 'Some Actor', 'Type': 'Person'}),
    ).item(_id);

    expect(result.failureOrNull, isA<UnavailableFailure>());
  });

  test('treats an item that is gone as a dead link', () async {
    final result = await _repository(
      FakeDioAdapter((_) async => jsonResponseBody(itemsResponse(const []))),
    ).item(_id);

    expect(result.failureOrNull, isA<UnavailableFailure>());
  });
}
