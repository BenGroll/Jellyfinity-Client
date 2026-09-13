import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/jellyfin/connected/JellyfinSessionApi.dart';

import '../../../support/connected_playback/FakeJellyfinServer.dart';

/// The capability post is the request every other part of connected
/// playback depends on: `/Sessions?ControllableByUserId=` returns only
/// sessions the server believes support remote control, and that belief
/// comes from here. A request Jellyfin refuses therefore does not just
/// lose a capability — it removes this install from every picker on the
/// account, including its own.
void main() {
  group('advertiseCapabilities', () {
    test('sends the capabilities Jellyfin can bind, as a JSON body', () async {
      final server = FakeJellyfinServer();
      final api = testSessionApi(server);

      final result = await api.advertiseCapabilities(
        supportsMediaControl: true,
      );

      expect(result.isOk, isTrue);
      expect(server.capabilityPosts, 1);

      final request = server.adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, JellyfinSessionApi.capabilitiesPath);
      // The body is the whole point: the query string form belongs to the
      // other route, and sending it here leaves the required body empty.
      expect(request.queryParameters, isEmpty);

      final body = request.data! as Map<String, Object?>;
      expect(body['PlayableMediaTypes'], ['Audio']);
      expect(body['SupportsMediaControl'], isTrue);
      expect(body['SupportsPersistentIdentifier'], isTrue);
    });

    test('advertises only real GeneralCommandType values', () async {
      final server = FakeJellyfinServer();
      final api = testSessionApi(server);

      await api.advertiseCapabilities(supportsMediaControl: true);

      final body = server.adapter.requests.single.data! as Map<String, Object?>;
      final commands = (body['SupportedCommands']! as List).cast<String>();

      expect(commands, isNotEmpty);
      expect(commands, everyElement(isIn(generalCommandTypes)));
      // The transport's own envelopes ride inside this one, so a build
      // that stopped advertising it would be invisible to its peers even
      // with a healthy session.
      expect(commands, contains(JellyfinSessionApi.envelopeCommandName));
      // Pause, next, previous and seek are PlaystateCommand values; a
      // session says it takes them by naming the general command that
      // carries them.
      expect(commands, contains('PlayState'));
    });

    test(
      'reports a refused capability post rather than swallowing it',
      () async {
        final server = FakeJellyfinServer()
          ..statusOverrides[JellyfinSessionApi.capabilitiesPath] = 400;
        final api = testSessionApi(server);

        final result = await api.advertiseCapabilities(
          supportsMediaControl: true,
        );

        expect(result.isErr, isTrue);
      },
    );
  });
}
