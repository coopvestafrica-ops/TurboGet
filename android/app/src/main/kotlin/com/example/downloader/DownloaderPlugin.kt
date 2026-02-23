package com.example.downloader

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class DownloaderPlugin: FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware {
    private lateinit var channel : MethodChannel
    private lateinit var eventChannel: EventChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val segmented = SegmentedDownloader()

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.example.downloader/methods")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "com.example.downloader/events")
        eventChannel.setStreamHandler(this)
        context = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDownload" -> {
                val id = call.argument<String>("id")!!
                val url = call.argument<String>("url")!!
                val dest = call.argument<String>("dest")!!
                // Launch a coroutine to download
                scope.launch {
                    try {
                        segmented.download(url, dest) { downloaded, total, progress ->
                            // send progress event to dart
                            val map = mapOf("id" to id, "downloaded" to downloaded, "total" to total, "progress" to progress, "status" to "downloading")
                            Handler(Looper.getMainLooper()).post {
                                eventSink?.success(map)
                            }
                        }
                        Handler(Looper.getMainLooper()).post {
                            eventSink?.success(mapOf("id" to id, "progress" to 100, "status" to "completed"))
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        Handler(Looper.getMainLooper()).post {
                            eventSink?.success(mapOf("id" to id, "status" to "failed", "error" to (e.message ?: "")))
                        }
                        result.error("DOWNLOAD_FAILED", e.message, null)
                    }
                }
            }
            "pauseDownload" -> {
                // TODO: implement pause logic (store state in segmented downloader)
                result.success(true)
            }
            "resumeDownload" -> {
                // TODO: implement resume logic
                result.success(true)
            }
            "cancelDownload" -> {
                // TODO: implement cancel logic
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        scope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }
}
