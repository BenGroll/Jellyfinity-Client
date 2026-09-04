/// Jellyfinity's playback vocabulary (v0.0.9, ADR-0013).
///
/// The queue is Jellyfinity's own application state ([PlaybackQueue],
/// [QueueEntry]), kept deliberately separate from the swappable engine
/// boundary ([PlaybackEngine]) that plays whatever order the queue
/// computes. [AudioSourceResolver] is the audio counterpart to
/// `ArtworkResolver`; [QueueRepository] persists the queue across
/// restarts.
///
/// Import this one file rather than reaching into the individual files.
library;

export 'AudioSourceResolver.dart';
export 'PlaybackEngine.dart';
export 'PlaybackFailure.dart';
export 'PlaybackQueue.dart';
export 'PlaybackSource.dart';
export 'playback_status.dart';
export 'QueueEntry.dart';
export 'QueueRepository.dart';
export 'repeat_mode.dart';
export 'stream_quality.dart';
