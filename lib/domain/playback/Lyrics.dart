import 'package:equatable/equatable.dart';

/// One line of a track's lyrics.
///
/// [start] is the position in the track this line begins at, when the
/// server's data carries reliable timing; `null` for a plain-text line.
class LyricLine extends Equatable {
  const LyricLine({required this.text, this.start});

  final String text;
  final Duration? start;

  @override
  List<Object?> get props => [text, start];
}

/// A track's lyrics, read on demand for the Lyrics view (v0.1.5).
///
/// [isSynchronized] is true only when every line carries a [LyricLine.start]
/// and they are in non-decreasing order — anything less is not reliable
/// enough to drive scrolling/highlighting (`Roadmap to v0.2.md` §v0.1.5:
/// "half-working synchronization must not ship"), so the view falls back to
/// plain lyrics instead.
class Lyrics extends Equatable {
  const Lyrics({required this.lines, required this.isSynchronized});

  final List<LyricLine> lines;
  final bool isSynchronized;

  @override
  List<Object?> get props => [lines, isSynchronized];
}
