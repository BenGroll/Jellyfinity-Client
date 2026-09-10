# audio_service_win 0.0.3

Vendored from https://pub.dev/packages/audio_service_win/versions/0.0.3
(https://github.com/HemantKArya/audio_service_win), under the included MIT license.

Local fixes:

- Convert a WinRT exception message to UTF-8 before writing to `std::cerr`,
  allowing the C++20 build required by current MSVC.
- Marshal WinRT media-button events through the main window before using
  Flutter's platform messenger.
- Send an empty artwork URI for absent artwork instead of the string `null`.

The application scopes C++20 to this plugin in `windows/CMakeLists.txt`.
Remove the local dependency when an upstream version supplies these fixes.
