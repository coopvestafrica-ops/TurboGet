package com.example.turboget.download

import android.content.Context
import java.io.File

/**
 * Manages multiple download tasks.
 */
class DownloadManager private constructor(private val context: Context) {
    
    companion object {
        @Volatile
        private var instance: DownloadManager? = null
        
        fun getInstance(context: Context): DownloadManager {
            return instance ?: synchronized(this) {
                instance ?: DownloadManager(context.applicationContext).also { instance = it }
            }
        }
    }
    
    private val activeTasks = mutableMapOf<String, DownloadTask>()
    private val maxConcurrentDownloads = 3
    
    /**
     * Start a new download
     */
    fun startDownload(
        downloadId: String,
        url: String,
        savePath: String,
        onProgress: (DownloadTask.DownloadProgress) -> Unit,
        onComplete: (Boolean, String?) -> Unit
    ) {
        // Check if already downloading
        if (activeTasks.containsKey(downloadId)) {
            return
        }
        
        // Check concurrent download limit
        if (activeTasks.size >= maxConcurrentDownloads) {
            // Queue the download
            return
        }
        
        val task = DownloadTask(
            downloadId = downloadId,
            url = url,
            savePath = savePath,
            onProgress = onProgress,
            onComplete = { success, error ->
                activeTasks.remove(downloadId)
                onComplete(success, error)
            }
        )
        
        activeTasks[downloadId] = task
        task.start()
    }
    
    /**
     * Pause a download
     */
    fun pauseDownload(downloadId: String) {
        activeTasks[downloadId]?.pause()
    }
    
    /**
     * Resume a download
     */
    fun resumeDownload(downloadId: String) {
        activeTasks[downloadId]?.resume()
    }
    
    /**
     * Cancel a download
     */
    fun cancelDownload(downloadId: String) {
        activeTasks[downloadId]?.cancel()
        activeTasks.remove(downloadId)
    }
    
    /**
     * Cancel all downloads
     */
    fun cancelAllDownloads() {
        activeTasks.values.forEach { it.cancel() }
        activeTasks.clear()
    }
    
    /**
     * Get number of active downloads
     */
    fun getActiveDownloadCount(): Int = activeTasks.size
    
    /**
     * Check if a download is active
     */
    fun isDownloadActive(downloadId: String): Boolean = activeTasks.containsKey(downloadId)
    
    /**
     * Get download status
     */
    fun getDownloadStatus(downloadId: String): DownloadStatus {
        val task = activeTasks[downloadId]
        return when {
            task == null -> DownloadStatus.IDLE
            task.isDownloading() -> DownloadStatus.DOWNLOADING
            task.isPaused() -> DownloadStatus.PAUSED
            task.isCancelled() -> DownloadStatus.CANCELLED
            else -> DownloadStatus.IDLE
        }
    }
    
    enum class DownloadStatus {
        IDLE,
        DOWNLOADING,
        PAUSED,
        CANCELLED
    }
}
