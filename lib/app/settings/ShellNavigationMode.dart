/// How the shell presents media-type context to the user.
///
/// Named `Shell`NavigationMode, not `NavigationMode`, because Flutter's own
/// `widgets` library already exports a `NavigationMode` enum (keyboard vs.
/// touch traversal) — colliding with it would force an import prefix at
/// every call site.
///
/// Jellyfinity's navigation is deliberately built as a swappable
/// presentation rather than one fixed layout — high configurability is a
/// stated product goal (`PHILOSOPHY.md` §9), not an afterthought bolted on
/// once a "final" nav shipped. Today, with only Music implemented, the
/// visible difference between the two modes is intentionally small (a
/// single, effectively inert "Music" pill shown or not); the payoff is the
/// seam itself, which later media types and modes slot into without
/// restructuring anything above it. See ADR-0014.
enum ShellNavigationMode {
  /// The persistent header shows a row of media-type "pills" beneath the
  /// search field, so switching what Home/Library/search are scoped to is
  /// a single tap.
  mediaPills,

  /// No pill row: Home and Library show one blended view across every
  /// available media type.
  unified;

  static const ShellNavigationMode fallback = ShellNavigationMode.mediaPills;

  static ShellNavigationMode? tryParse(String? raw) => switch (raw) {
    'mediaPills' => ShellNavigationMode.mediaPills,
    'unified' => ShellNavigationMode.unified,
    _ => null,
  };
}
