import '../../../../domain/media/media.dart';

/// A track's length as a listener reads it: `3:42`, or `1:02:11` for the
/// long ones. Never `03:42`, and never a leading `0:` hour.
String formatDuration(Duration duration) {
  final seconds = duration.inSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final twoDigit = s.toString().padLeft(2, '0');
  if (h == 0) return '$m:$twoDigit';
  return '$h:${m.toString().padLeft(2, '0')}:$twoDigit';
}

/// A collection's running time in words — `48 min`, `3 hr 12 min` — for
/// the places a precise second is noise.
String formatRunningTime(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours hr' : '$hours hr $rest min';
}

/// `1 song` / `12 songs`, or null when the server did not say.
String? formatTrackCount(int? count) {
  if (count == null) return null;
  return count == 1 ? '1 song' : '$count songs';
}

/// The credits line under a title, or `null` when there are none — so a
/// caller can fall back to something else instead of leaving a blank row.
String? formatArtists(List<ArtistRef> artists) {
  if (artists.isEmpty) return null;
  return artists.display;
}

/// Joins the parts of a subtitle that actually exist: `1959 · 5 songs`.
String joinDetails(List<String?> parts) =>
    parts.where((part) => part != null && part.isNotEmpty).join(' · ');
