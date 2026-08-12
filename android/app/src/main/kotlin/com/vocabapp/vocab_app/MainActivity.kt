package com.vocabapp.vocab_app

import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * 原生 TTS 通道：直接调用 Android 系统 TextToSpeech（Google TTS 等），
 * 绕开 flutter_tts 插件在小米等系统上的兼容问题。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "vocab_app/tts"
    private var tts: TextToSpeech? = null
    private var ready = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> {
                        tts?.shutdown()
                        tts = TextToSpeech(applicationContext) { status ->
                            ready = status == TextToSpeech.SUCCESS
                            if (ready) {
                                val engine = tts
                                if (engine != null) {
                                    // 优先英文（美式），失败则默认引擎语言
                                    val langResult = engine.setLanguage(Locale.US)
                                    if (langResult == TextToSpeech.LANG_MISSING_DATA ||
                                        langResult == TextToSpeech.LANG_NOT_SUPPORTED
                                    ) {
                                        ready = false
                                    } else {
                                        engine.setSpeechRate(0.85f)
                                        engine.setPitch(1.0f)
                                    }
                                }
                            }
                            result.success(ready)
                        }
                    }
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        val t = tts
                        if (!ready || t == null || text.isEmpty()) {
                            result.success(false)
                        } else {
                            val ok = t.speak(text, TextToSpeech.QUEUE_FLUSH, null, "utterance")
                            result.success(ok == TextToSpeech.SUCCESS)
                        }
                    }
                    "stop" -> {
                        tts?.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        tts?.shutdown()
        super.onDestroy()
    }
}
