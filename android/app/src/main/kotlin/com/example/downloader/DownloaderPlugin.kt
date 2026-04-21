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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap

class DownloaderPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val segmented = SegmentedDownloader()

    /** Per-download bookkeeping so we can pause / resume / cancel. */
    private data class Handle(val job: Job, val control: SegmentedDownloader.Control)

    private val handles = ConcurrentHashMap<String, Handle>()

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
                val id = call.argument<String>("id")
                val url = call.argument<String>("url")
                val dest = call.argument<String>("dest")
                if (id == null || url == null || dest == null) {
                    result.error("BAD_ARGS", "id, url and dest are required", null)
                    return
                }
                if (handles.containsKey(id)) {
                    result.error("ALREADY_RUNNING", "Download $id is already in flight", null)
                    return
                }
                val control = SegmentedDownloader.Control()
                val job = scope.launch {
                    try {
                        segmented.download(url, dest, control) { downloaded, total, progress ->
                            post(
                                mapOf(
                                    "id" to id,
                                    "downloaded" to downloaded,
                                    "total" to total,
                                    "progress" to progress,
                                    "status" to if (control.paused) "paused" else "downloading",
                                )
                            )
                        }
                        if (control.cancelled) {
                            post(mapOf("id" to id, "status" to "cancelled"))
                        } else {
                            post(mapOf("id" to id, "progress" to 100, "status" to "completed"))
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                        post(
                            mapOf(
                                "id" to id,
                                "status" to "failed",
                                "error" to (e.message ?: ""),
                            )
                        )
                    } finally {
                        handles.remove(id)
                    }
                }
                handles[id] = Handle(job, control)
                result.success(true)
            }
            "pauseDownload" -> {
                val id = call.argument<String>("id") ?: run {
                    result.error("BAD_ARGS", "id is required", null); return
                }
                handles[id]?.control?.paused = true
                result.success(true)
            }
            "resumeDownload" -> {
                val id = call.argument<String>("id") ?: run {
                    result.error("BAD_ARGS", "id is required", null); return
                }
                handles[id]?.control?.let {
                    it.paused = false
                    synchronized(it.lock) { (it.lock as Object).notifyAll() }
                }
                result.success(true)
            }
            "cancelDownload" -> {
                val id = call.argument<String>("id") ?: run {
                    result.error("BAD_ARGS", "id is required", null); return
                }
                handles[id]?.let {
                    it.control.cancelled = true
                    synchronized(it.control.lock) { (it.control.lock as Object).notifyAll() }
                }
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun post(map: Map<String, Any?>) {
        main.post { eventSink?.success(map) }
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
        // Cooperatively cancel every in-flight download before tearing the
        // coroutine scope down so sockets and files are released cleanly.
        handles.values.forEach {
            it.control.cancelled = true
            synchronized(it.control.lock) { (it.control.lock as Object).notifyAll() }
        }
        handles.clear()
        scope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
