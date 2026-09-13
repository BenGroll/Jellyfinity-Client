package io.nachbar.jellyfinity

import android.app.UiModeManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// audio_service needs the Flutter engine it manages, not the one
// FlutterActivity would create on its own — AudioServiceActivity (its
// own FlutterActivity subclass) provides that (ADR-0013).
class MainActivity : AudioServiceActivity() {
    private var displayEventSink: EventChannel.EventSink? = null

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
                    registerReceiver(
                        displayStateReceiver,
                        IntentFilter().apply {
                            addAction(Intent.ACTION_SCREEN_ON)
                            addAction(Intent.ACTION_SCREEN_OFF)
                        },
                    )
                }

                override fun onCancel(arguments: Any?) {
                    displayEventSink = null
                    unregisterReceiver(displayStateReceiver)
                }
            },
        )
    }

    private fun isTelevision(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        return uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature("amazon.hardware.fire_tv")
    }
}
