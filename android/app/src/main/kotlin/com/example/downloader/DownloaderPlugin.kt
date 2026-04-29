package com.example.downloader

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
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
    private data class Handle(
        val job: Job,
        val control: SegmentedDownloader.Control,
        val filename: String,
    )

    private val handles = ConcurrentHashMap<String, Handle>()

    init {
        instance = this
    }

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
                val sha = call.argument<String>("sha256")
                val bps = (call.argument<Number>("bytesPerSecond"))?.toLong() ?: 0L
                if (id == null || url == null || dest == null) {
                    result.error("BAD_ARGS", "id, url and dest are required", null)
                    return
                }
                if (handles.containsKey(id)) {
                    result.error("ALREADY_RUNNING", "Download $id is already in flight", null)
                    return
                }
                val control = SegmentedDownloader.Control()
                control.bytesPerSecond = bps
                val filename = dest.substringAfterLast('/')
                startForegroundIfNeeded()
                val job = scope.launch {
                    try {
                        segmented.download(url, dest, control, sha) { downloaded, total, progress ->
                            val status = if (control.paused) "paused" else "downloading"
                            post(
                                mapOf(
                                    "id" to id,
                                    "downloaded" to downloaded,
                                    "total" to total,
                                    "progress" to progress,
                                    "status" to status,
                                ),
                            )
                            updateNotification(id, filename, progress, status, downloaded, total)
                        }
                        if (control.cancelled) {
                            post(mapOf("id" to id, "status" to "cancelled"))
                            updateNotification(id, filename, 0, "cancelled", 0, 0)
                        } else {
                            post(mapOf("id" to id, "progress" to 100, "status" to "completed"))
                            updateNotification(id, filename, 100, "completed", 0, 0)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                        post(
                            mapOf(
                                "id" to id,
                                "status" to "failed",
                                "error" to (e.message ?: ""),
                            ),
                        )
                        updateNotification(id, filename, 0, "failed", 0, 0)
                    } finally {
                        handles.remove(id)
                    }
                }
                handles[id] = Handle(job, control, filename)
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
            "pauseAllDownloads" -> {
                handles.values.forEach { it.control.paused = true }
                result.success(true)
            }
            "resumeAllDownloads" -> {
                handles.values.forEach {
                    it.control.paused = false
                    synchronized(it.control.lock) { (it.control.lock as Object).notifyAll() }
                }
                result.success(true)
            }
            "setBandwidthLimit" -> {
                val bps = (call.argument<Number>("bytesPerSecond"))?.toLong() ?: 0L
                handles.values.forEach { it.control.bytesPerSecond = bps }
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun startForegroundIfNeeded() {
        val ctx = context ?: return
        val intent = Intent(ctx, DownloadForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ctx.startForegroundService(intent)
        } else {
            ctx.startService(intent)
        }
    }

    private fun updateNotification(
        id: String,
        filename: String,
        progress: Int,
        status: String,
        downloaded: Long,
        total: Long,
    ) {
        val ctx = context ?: return
        val intent = Intent(ctx, DownloadForegroundService::class.java).apply {
            action = DownloadForegroundService.ACTION_UPDATE
            putExtra(DownloadForegroundService.EXTRA_ID, id)
            putExtra(DownloadForegroundService.EXTRA_FILENAME, filename)
            putExtra(DownloadForegroundService.EXTRA_PROGRESS, progress)
            putExtra(DownloadForegroundService.EXTRA_STATUS, status)
            putExtra(DownloadForegroundService.EXTRA_DOWNLOADED, downloaded)
            putExtra(DownloadForegroundService.EXTRA_TOTAL, total)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ctx.startForegroundService(intent)
        } else {
            ctx.startService(intent)
        }
    }

    /** Called by [DownloadActionReceiver] for notification taps. */
    fun handleAction(id: String, action: String) {
        when (action) {
            "pause" -> handles[id]?.control?.paused = true
            "resume" -> handles[id]?.control?.let {
                it.paused = false
                synchronized(it.lock) { (it.lock as Object).notifyAll() }
            }
            "cancel" -> handles[id]?.let {
                it.control.cancelled = true
                synchronized(it.control.lock) { (it.control.lock as Object).notifyAll() }
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        handles.values.forEach {
            it.control.cancelled = true
            synchronized(it.control.lock) { (it.control.lock as Object).notifyAll() }
        }
        handles.clear()
        scope.cancel()
        if (instance === this) instance = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
    override fun onCancel(arguments: Any?) { eventSink = null }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    private fun post(payload: Map<String, Any?>) {
        main.post { eventSink?.success(payload) }
    }

    companion object {
        @Volatile private var instance: DownloaderPlugin? = null

        @JvmStatic
        fun handleNotificationAction(id: String, action: String) {
            instance?.handleAction(id, action)
        }
    }
}
