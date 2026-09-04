/// One kind of media the shell can scope Home/Library/search to.
///
/// A single case today (Music is the only implemented library — Movies/TV
/// are entities-only per ADR-0011, Audiobooks/Ebooks don't exist yet). New
/// cases land here as their libraries ship; nothing above [MediaContext]
/// needs to change shape when they do. See ADR-0014.
enum MediaType {
  music;

  String get label => switch (this) {
    MediaType.music => 'Music',
  };
}
