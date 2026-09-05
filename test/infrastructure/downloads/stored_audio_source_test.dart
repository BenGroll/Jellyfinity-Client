import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/infrastructure/downloads/StoredAudioSource.dart';

import '../../support/download_fakes.dart';

const _id = MediaId(serverId: 'server-1', itemId: 'track-1');

void main() {
  late InMemoryDownloadStore store;
  late FakeDownloadEngine engine;
  late StoredAudioSource source;

  setUp(() {
    store = InMemoryDownloadStore();
    engine = FakeDownloadEngine();
    source = StoredAudioSource(store, engine);
  });

  test('answers null when nothing was ever downloaded', () async {
    expect(await source.addressFor(_id), isNull);
  });

  test('answers the engine\'s address once the record is completed', () async {
    store.records[_id] = downloadRecord(_id, state: DownloadState.completed);
    engine.stored[_id] = Uri.file('/downloads/track-1/audio.flac');

    expect(
      await source.addressFor(_id),
      Uri.file('/downloads/track-1/audio.flac'),
    );
  });

  test('answers null while the record is still downloading', () async {
    store.records[_id] = downloadRecord(_id, state: DownloadState.downloading);
    engine.stored[_id] = Uri.file('/downloads/track-1/audio.part');

    // A partial file existing is not the same as a completed download —
    // playback must not be handed an address that is still being
    // written to.
    expect(await source.addressFor(_id), isNull);
  });

  test(
    'answers null when the record says complete but the file is gone',
    () async {
      store.records[_id] = downloadRecord(_id, state: DownloadState.completed);
      // Nothing registered in engine.stored — the record and the disk
      // disagree, and playback must fall through to streaming rather than
      // resolving to a dead address.
      expect(await source.addressFor(_id), isNull);
    },
  );
}
