package com.yovelou.yove_lou

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    // Decoding a song takes a moment, so it runs off the main thread.
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yove_lou/bpm")
            .setMethodCallHandler { call, result ->
                if (call.method != "analyze") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "path is required", null)
                    return@setMethodCallHandler
                }
                worker.execute {
                    val analysis = try {
                        BpmDetector.analyze(path)
                    } catch (e: Exception) {
                        null
                    }
                    val reply: Map<String, Any?>? = analysis?.let {
                        val bytes = ByteBuffer.allocate(it.env.size * 4).order(ByteOrder.LITTLE_ENDIAN)
                        bytes.asFloatBuffer().put(it.env)
                        mapOf(
                            "bpm" to it.bpm,
                            "firstBeat" to it.firstBeat,
                            "envRate" to BpmDetector.ENV_RATE,
                            "env" to bytes.array(),
                        )
                    }
                    runOnUiThread { result.success(reply) }
                }
            }
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }
}
