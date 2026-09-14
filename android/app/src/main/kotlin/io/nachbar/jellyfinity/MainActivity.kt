package io.nachbar.jellyfinity

import android.app.UiModeManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.media.AudioManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// audio_service needs the Flutter engine it manages, not the one
// FlutterActivity would create on its own — AudioServiceActivity (its
// own FlutterActivity subclass) provides that (ADR-0013).
class MainActivity : AudioServiceActivity() {
    private var displayEventSink: EventChannel.EventSink? = null
    private var displayReceiverRegistered = false

    // ACTION_SCREEN_ON/OFF are protected broadcasts Android refuses to
    // deliver to a manifest-declared receiver, so this has to be
    // registered at runtime — only for as long as Dart is actually
    // listening (v0.5.9).
    private val displayStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_ON -> displayEventSink?.success(true)
                Intent.ACTION_SCREEN_OFF -> displayEventSink?.success(false)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.nachbar.jellyfinity/device",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTelevision" -> result.success(isTelevision())
                "getSystemVolume" -> result.success(getSystemVolume())
                "setSystemVolume" -> {
                    val level = call.arguments as? Double
                    if (level == null) {
                        result.error(
                            "invalid_volume",
                            "A numeric volume between 0.0 and 1.0 is required.",
                            null,
                        )
                    } else {
                        setSystemVolume(level)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.nachbar.jellyfinity/device/display",
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    displayEventSink = events
                    // configureFlutterEngine can run again on the same
                    // Activity (an engine reattach), which would otherwise
                    // register the same receiver instance twice.
                    if (!displayReceiverRegistered) {
                        registerReceiver(
                            displayStateReceiver,
                            IntentFilter().apply {
                                addAction(Intent.ACTION_SCREEN_ON)
                                addAction(Intent.ACTION_SCREEN_OFF)
                            },
                        )
                        displayReceiverRegistered = true
                    }
                }

                override fun onCancel(arguments: Any?) {
                    displayEventSink = null
                    if (displayReceiverRegistered) {
                        unregisterReceiver(displayStateReceiver)
                        displayReceiverRegistered = false
                    }
                }
            },
        )
    }

    private fun isTelevision(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        return uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature("amazon.hardware.fire_tv")
    }

    // v0.6.0: the real per-platform execution path RemoteCommandKind.setVolume
    // needs — STREAM_MUSIC is the same stream the hardware volume keys and
    // every Jellyfinity-played track already use, so a remote-set level and
    // a listener reaching for the volume rocker never disagree about which
    // stream "the volume" means.
    private fun audioManager(): AudioManager =
        getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun getSystemVolume(): Double {
        val manager = audioManager()
        val max = manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 0.0
        return manager.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
    }

    private fun setSystemVolume(level: Double) {
        val manager = audioManager()
        val max = manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val clamped = level.coerceIn(0.0, 1.0)
        val target = Math.round(clamped * max).toInt()
        manager.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
    }
}
