package kr.fingersnap.fingerbell

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var toneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playAlertTone" -> {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                    if (audioManager != null && audioManager.ringerMode != AudioManager.RINGER_MODE_NORMAL) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val durationMs = (call.argument<Int>("durationMs") ?: 400).coerceIn(100, 2500)
                    try {
                        val gen = toneGenerator ?: ToneGenerator(AudioManager.STREAM_NOTIFICATION, 85).also {
                            toneGenerator = it
                        }
                        gen.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, durationMs)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            toneGenerator?.release()
        } catch (_: Exception) {
        }
        toneGenerator = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_NAME = "kr.fingersnap.fingerbell/alert_tone"
    }
}
