import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/playback/LocalFirstAudioSourceResolver.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/downloads/LocalAudioSource.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/playback/stream_quality.dart';

import '../../support/playback_fakes.dart';

const _id = MediaId(serverId: 'server-1', itemId: 'track-1');

class _StubLocalAudioSource implements LocalAudioSource {
  Uri? address;

  @override
  Future<Uri?> addressFor(MediaId id) async => address;
}

void main() {
  test('prefers a completed download over the remote address', () async {
    final local = _StubLocalAudioSource()
      ..address = Uri.file('/downloads/track-1/audio.flac');
    final remote = FakeAudioSourceResolver();
    final resolver = LocalFirstAudioSourceResolver(remote, local);

    final result = await resolver.resolve(_id);

    expect(result.valueOrNull, Uri.file('/downloads/track-1/audio.flac'));
    // The server was never asked — nothing streams when a local file
    // already answers.
    expect(remote.requestedQuality, isEmpty);
  });

  test('falls back to the server when nothing is downloaded', () async {
    final local = _StubLocalAudioSource();
    final remote = FakeAudioSourceResolver();
    final resolver = LocalFirstAudioSourceResolver(remote, local);

    final result = await resolver.resolve(_id, quality: StreamQuality.high);

    expect(
      result.valueOrNull,
      Uri.parse('https://media.example.com/Audio/track-1/stream'),
    );
    expect(remote.requestedQuality['track-1'], StreamQuality.high);
  });

  test('a remote failure surfaces when there is no local file', () async {
    final local = _StubLocalAudioSource();
    final remote = FakeAudioSourceResolver()..unresolvable.add('track-1');
    final resolver = LocalFirstAudioSourceResolver(remote, local);

    final result = await resolver.resolve(_id);

    expect(result.isErr, isTrue);
    expect(result.failureOrNull, isA<UnavailableFailure>());
  });
}
