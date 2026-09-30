package com.ember.app

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServicePlugin
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.ember/python"
    private val executor = Executors.newSingleThreadExecutor()

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return AudioServicePlugin.getFlutterEngine(context)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val py = Python.getInstance()
            val module = py.getModule("android_api")
            
            when (call.method) {
                "search" -> {
                    val query = call.argument<String>("query")
                    val filter = call.argument<String>("filter")
                    executor.execute {
                        try {
                            val res = module.callAttr("search", query, filter)
                            val kotlinList = res.asList().map { it.asMap().mapKeys { k -> k.key.toString() }.mapValues { v -> v.value.toString() } }
                            runOnUiThread { result.success(kotlinList) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PYTHON_ERROR", e.message, null) }
                        }
                    }
                }
                "similar" -> {
                    val seedId = call.argument<String>("seedId")
                    executor.execute {
                        try {
                            val res = module.callAttr("similar", seedId)
                            val kotlinList = res.asList().map { it.asMap().mapKeys { k -> k.key.toString() }.mapValues { v -> v.value.toString() } }
                            runOnUiThread { result.success(kotlinList) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PYTHON_ERROR", e.message, null) }
                        }
                    }
                }
                "get_stream_url" -> {
                    val videoId = call.argument<String>("videoId")
                    executor.execute {
                        try {
                            val res = module.callAttr("get_stream_url", videoId).asMap()
                            val kotlinMap = res.mapKeys { it.key.toString() }.mapValues { it.value?.toString() }
                            runOnUiThread { result.success(kotlinMap) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PYTHON_ERROR", e.message, null) }
                        }
                    }
                }
                "get_home" -> {
                    executor.execute {
                        try {
                            val res = module.callAttr("get_home").toString()
                            runOnUiThread { result.success(res) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PYTHON_ERROR", e.message, null) }
                        }
                    }
                }
                "lyrics" -> {
                    val videoId = call.argument<String>("videoId")
                    executor.execute {
                        try {
                            val res = module.callAttr("lyrics", videoId)?.toString()
                            runOnUiThread { result.success(res) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PYTHON_ERROR", e.message, null) }
                        }
                    }
                }
                "get_artist_details" -> {
                    val browseId = call.argument<String>("browse_id")
                    executor.execute {
                        try {
                            val res = module.callAttr("get_artist_details", browseId)?.toString()
                            runOnUiThread { result.success(res) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PYTHON_ERROR", e.message, null) }
                        }
                    }
                }
                "import_playlist" -> {
                    val identifier = call.argument<String>("identifier")
                    executor.execute {
                        try {
                            val res = module.callAttr("import_playlist", identifier)?.toString()
                            runOnUiThread { result.success(res) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PYTHON_ERROR", e.message, null) }
                        }
                    }
                }
                "build_affinity_graph" -> {
                    val historyJson = call.argument<String>("history_json")
                    executor.execute {
                        try {
                            val res = module.callAttr("build_affinity_graph", historyJson)?.toString()
                            runOnUiThread { result.success(res) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PYTHON_ERROR", e.message, null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
