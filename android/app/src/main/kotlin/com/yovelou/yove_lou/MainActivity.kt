package com.yovelou.yove_lou

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    // Decoding a song takes a moment, so it runs off the main thread.
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yove_lou/bpm")
            .setMethodCallHandler { call, result ->
                if (call.method != "detect") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "path is required", null)
                    return@setMethodCallHandler
                }
                worker.execute {
                    val bpm = try {
                        BpmDetector.detect(path)
                    } catch (e: Exception) {
                        null
                    }
                    runOnUiThread { result.success(bpm) }
                }
            }
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }
}
