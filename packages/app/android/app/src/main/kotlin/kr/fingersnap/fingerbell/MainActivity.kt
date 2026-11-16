package kr.fingersnap.fingerbell

import android.content.Context
import android.content.Intent
import android.content.ActivityNotFoundException
import android.net.Uri
import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var toneGenerator: ToneGenerator? = null
    private var linksChannel: MethodChannel? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        linksChannel?.invokeMethod("onLink", intent.dataString)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        linksChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kr.fingersnap.fingerbell/apps",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialLink" -> result.success(intent.dataString)
                    "open" -> {
                        val uri = call.argument<String>("uri")?.let { Uri.parse(it) }
                        val target = when (uri?.host) {
                            "bank" -> "kr.fingersnap.fingerbell"
                            "sms" -> "kr.fingersnap.fingerbell.sms"
                            "call" -> "kr.fingersnap.fingerbell.call"
                            else -> null
                        }
                        if (uri?.scheme != "fingerbell" || target == null) {
                            result.error("invalid_link", "앱 주소를 확인해 주세요", null)
                        } else {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, uri).apply {
                                    setClassName(target, "kr.fingersnap.fingerbell.MainActivity")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                })
                                result.success(null)
                            } catch (_: ActivityNotFoundException) {
                                result.error("app_missing", "앱을 함께 설치해 주세요", null)
                            } catch (_: SecurityException) {
                                result.error("app_unavailable", "앱을 열 수 없어요", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PREFS_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            if (packageName != OWNER_PACKAGE) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            when (call.method) {
                "getAll" -> {
                    val out = HashMap<String, Any>()
                    for ((k, v) in prefs.all) {
                        if (v is Boolean || v is String) out[k] = v
                    }
                    result.success(out)
                }
                "setBool" -> {
                    val key = call.argument<String>("key")
                    val value = call.argument<Boolean>("value")
                    if (key != null && value != null) {
                        prefs.edit().putBoolean(key, value).apply()
                    }
                    result.success(null)
                }
                "setString" -> {
                    val key = call.argument<String>("key")
                    val value = call.argument<String>("value")
                    if (key != null && value != null) {
                        prefs.edit().putString(key, value).apply()
                    }
                    result.success(null)
                }
                "clear" -> {
                    prefs.edit().clear().apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARED_PREFS_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAll" -> result.success(readSharedPrefsFromProvider())
                else -> result.notImplemented()
            }
        }
    }

    private fun readSharedPrefsFromProvider(): Map<String, Any> {
        val out = HashMap<String, Any>()
        try {
            contentResolver.query(SHARED_PREFS_URI, null, null, null, null)?.use { cursor ->
                val keyIdx = cursor.getColumnIndex("key")
                val typeIdx = cursor.getColumnIndex("type")
                val valueIdx = cursor.getColumnIndex("value")
                if (keyIdx < 0 || typeIdx < 0 || valueIdx < 0) return emptyMap()
                while (cursor.moveToNext()) {
                    val key = cursor.getString(keyIdx) ?: continue
                    val type = cursor.getString(typeIdx) ?: continue
                    val raw = cursor.getString(valueIdx) ?: continue
                    when (type) {
                        "string" -> out[key] = raw
                        "bool" -> if (raw == "true" || raw == "false") out[key] = (raw == "true")
                    }
                }
            }
        } catch (_: Exception) {
            return emptyMap()
        }
        return out
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
        private const val OWNER_PACKAGE = "kr.fingersnap.fingerbell"
        private const val PREFS_NAME = "fingerbell_prefs"
        private const val CHANNEL_NAME = "kr.fingersnap.fingerbell/alert_tone"
        private const val PREFS_CHANNEL_NAME = "kr.fingersnap.fingerbell/prefs"
        private const val SHARED_PREFS_CHANNEL_NAME = "kr.fingersnap.fingerbell/shared_prefs"
        private val SHARED_PREFS_URI: Uri = Uri.parse("content://kr.fingersnap.fingerbell.prefs/prefs")
    }
}
