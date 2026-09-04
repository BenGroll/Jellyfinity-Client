package io.nachbar.jellyfinity

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service needs the Flutter engine it manages, not the one
// FlutterActivity would create on its own — AudioServiceActivity (its
// own FlutterActivity subclass) provides that (ADR-0013).
class MainActivity : AudioServiceActivity()
