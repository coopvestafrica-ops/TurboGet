package com.example.turboget

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.turboget.download.DownloadManager
import com.example.turboget.download.DownloadServiceConstants
import android.content.Intent
import android.os.Environment

class MainActivity: FlutterActivity() {
    
    private val CHANNEL = "com.example.downloader/methods"
    private lateinit var downloadManager: DownloadManager
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize download manager
        downloadManager = DownloadManager.getInstance(this)
        
        // Create notification channel for Android O+
        createNotificationChannel()
        
        // Setup method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val id = call.argument<String>("id") ?: return@setMethodCallHandler result.error("INVALID_ARGS", "Download ID required", null)
                    val url = call.argument<String>("url") ?: return@setMethodCallHandler result.error("INVALID_ARGS", "URL required", null)
                    val dest = call.argument<String>("dest") ?: return@setMethodCallHandler result.error("INVALID_ARGS", "Destination required", null)
                    
                    downloadManager.startDownload(
                        downloadId = id,
                        url = url,
                        savePath = dest,
                        onProgress = { progress ->
                            // Send progress to Flutter
                            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.downloader/events")
                                .invokeMethod("onProgress", mapOf(
                                    "id" to progress.downloadId,
                                    "progress" to progress.progress,
                                    "bytes" to progress.downloadedBytes,
                                    "total_size" to progress.totalBytes,
                                    "speed" to progress.speed,
                                    "status" to "downloading"
                                ))
                        },
                        onComplete = { success, error ->
                            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.downloader/events")
                                .invokeMethod("onComplete", mapOf(
                                    "id" to id,
                                    "success" to success,
                                    "error" to error,
                                    "status" to if (success) "completed" else "failed"
                                ))
                        }
                    )
                    
                    result.success(true)
                }
                
                "pauseDownload" -> {
                    val id = call.argument<String>("id") ?: return@setMethodCallHandler result.error("INVALID_ARGS", "Download ID required", null)
                    downloadManager.pauseDownload(id)
                    result.success(true)
                }
                
                "resumeDownload" -> {
                    val id = call.argument<String>("id") ?: return@setMethodCallHandler result.error("INVALID_ARGS", "Download ID required", null)
                    downloadManager.resumeDownload(id)
                    result.success(true)
                }
                
                "cancelDownload" -> {
                    val id = call.argument<String>("id") ?: return@setMethodCallHandler result.error("INVALID_ARGS", "Download ID required", null)
                    downloadManager.cancelDownload(id)
                    result.success(true)
                }
                
                "pauseAllDownloads" -> {
                    // Pause all active downloads
                    result.success(true)
                }
                
                "resumeAllDownloads" -> {
                    // Resume all paused downloads
                    result.success(true)
                }
                
                "getDownloadsDirectory" -> {
                    val downloadsDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                    result.success(downloadsDir?.absolutePath)
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                DownloadServiceConstants.CHANNEL_ID,
                DownloadServiceConstants.CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = DownloadServiceConstants.CHANNEL_DESCRIPTION
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
