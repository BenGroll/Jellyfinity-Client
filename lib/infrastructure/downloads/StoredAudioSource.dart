import 'package:injectable/injectable.dart';

import '../../domain/downloads/DownloadEngine.dart';
import '../../domain/downloads/download_state.dart';
import '../../domain/downloads/DownloadStore.dart';
import '../../domain/downloads/LocalAudioSource.dart';
import '../../domain/downloads/TrackDownload.dart';
import '../../domain/media/MediaId.dart';
import '../../core/result/result.dart';

/// [LocalAudioSource] over the download records and the engine's
/// storage.
///
/// Both halves have to agree before playback will use a local file:
/// the record must say the download completed, *and* the file must
/// still be there. A record without its file (storage cleared by the
/// user, an OS-level restore that did not bring media back) falls
/// through to streaming instead of handing the player an address that
/// resolves to nothing — the honest behaviour, and the one that keeps
/// `PlaybackCubit`'s existing failure handling meaningful.
@LazySingleton(as: LocalAudioSource)
class StoredAudioSource implements LocalAudioSource {
  StoredAudioSource(this._store, this._engine);

  final DownloadStore _store;
  final DownloadEngine _engine;

  @override
  Future<Uri?> addressFor(MediaId id) async {
    final record = await _store.find(id);
    if (record case Ok<TrackDownload?>(:final value)) {
      if (value?.state != DownloadState.completed) return null;
      return _engine.locate(id);
    }
    return null;
  }
}
