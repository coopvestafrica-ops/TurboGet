package com.example.turboget.download

import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.io.RandomAccessFile
import java.io.File
import kotlinx.coroutines.*

/**
 * Download task that handles downloading a single file.
 * Supports pause, resume, and cancellation.
 */
class DownloadTask(
    private val downloadId: String,
    private val url: String,
    private val savePath: String,
    private val onProgress: (DownloadProgress) -> Unit,
    private val onComplete: (Boolean, String?) -> Unit
) {
    
    private var connection: HttpURLConnection? = null
    private var downloadThread: Thread? = null
    private var isPaused = false
    private var isCancelled = false
    private var downloadedBytes = 0L
    private var totalBytes = 0L
    private var tempFile: File? = null
    private var resumePosition = 0L
    
    data class DownloadProgress(
        val downloadId: String,
        val downloadedBytes: Long,
        val totalBytes: Long,
        val progress: Int,
        val speed: Double // bytes per second
    )
    
    /**
     * Start the download
     */
    fun start() {
        downloadThread = Thread {
            try {
                // Create temp file for partial downloads
                tempFile = File("$savePath.tmp")
                
                // Get initial file size if resuming
                if (tempFile!!.exists()) {
                    resumePosition = tempFile!!.length()
                }
                
                download(resumePosition)
            } catch (e: Exception) {
                onComplete(false, e.message)
            }
        }
        downloadThread?.start()
    }
    
    /**
     * Pause the download
     */
    fun pause() {
        isPaused = true
    }
    
    /**
     * Resume the download
     */
    fun resume() {
        isPaused = false
        synchronized(this) {
            (this as java.lang.Object).notify()
        }
    }
    
    /**
     * Cancel the download
     */
    fun cancel() {
        isCancelled = true
        connection?.disconnect()
        downloadThread?.interrupt()
        tempFile?.delete()
    }
    
    /**
     * Get download status
     */
    fun isDownloading() = downloadThread?.isAlive == true && !isPaused
    fun isPaused() = isPaused
    fun isCancelled() = isCancelled
    
    private fun download(startPosition: Long) {
        var inputStream: InputStream? = null
        var outputStream: RandomAccessFile? = null
        
        try {
            val urlObj = URL(url)
            connection = urlObj.openConnection() as HttpURLConnection
            
            // Set request properties
            connection?.apply {
                requestMethod = "GET"
                connectTimeout = 15000
                readTimeout = 30000
                setRequestProperty("User-Agent", "TurboGet/1.0")
                
                // If resuming, set range header
                if (startPosition > 0) {
                    setRequestProperty("Range", "bytes=$startPosition-")
                }
            }
            
            // Connect
            connection?.connect()
            
            // Check response code
            val responseCode = connection?.responseCode ?: 0
            if (responseCode != 200 && responseCode != 206) {
                throw Exception("Server returned error: $responseCode")
            }
            
            // Get content length
            totalBytes = connection?.contentLength?.toLong() ?: 0L
            if (startPosition > 0 && responseCode == 206) {
                // For resume, add start position to content length
                totalBytes += startPosition
            }
            
            // Open output file
            outputStream = RandomAccessFile(tempFile, "rw")
            if (startPosition > 0) {
                outputStream.seek(startPosition)
            }
            
            // Start downloading
            inputStream = connection?.inputStream
            val buffer = ByteArray(8192)
            var bytesRead: Int
            var lastProgressUpdate = System.currentTimeMillis()
            val startTime = System.currentTimeMillis()
            var totalRead = startPosition
            
            inputStream?.use { input ->
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    // Check for pause
                    while (isPaused && !isCancelled) {
                        synchronized(this) {
                            try {
                                (this as java.lang.Object).wait()
                            } catch (e: InterruptedException) {
                                break
                            }
                        }
                    }
                    
                    // Check for cancellation
                    if (isCancelled) {
                        return
                    }
                    
                    // Write to file
                    outputStream.write(buffer, 0, bytesRead)
                    downloadedBytes += bytesRead
                    totalRead += bytesRead
                    
                    // Update progress (max once per 500ms)
                    val currentTime = System.currentTimeMillis()
                    if (currentTime - lastProgressUpdate > 500) {
                        val elapsedSeconds = (currentTime - startTime) / 1000.0
                        val speed = if (elapsedSeconds > 0) totalRead / elapsedSeconds else 0.0
                        val progress = if (totalBytes > 0) ((totalRead * 100) / totalBytes).toInt() else 0
                        
                        onProgress(DownloadProgress(
                            downloadId = this@DownloadTask.downloadId,
                            downloadedBytes = totalRead,
                            totalBytes = totalBytes,
                            progress = progress,
                            speed = speed
                        ))
                        
                        lastProgressUpdate = currentTime
                    }
                }
            }
            
            // Download complete - move temp file to final location
            outputStream.close()
            inputStream?.close()
            
            val finalFile = File(savePath)
            tempFile?.renameTo(finalFile)
            
            onProgress(DownloadProgress(
                downloadId = downloadId,
                downloadedBytes = totalRead,
                totalBytes = totalBytes,
                progress = 100,
                speed = 0.0
            ))
            
            onComplete(true, null)
            
        } catch (e: Exception) {
            // Clean up
            outputStream?.close()
            inputStream?.close()
            
            if (!isCancelled) {
                onComplete(false, e.message)
            }
        }
    }
}
