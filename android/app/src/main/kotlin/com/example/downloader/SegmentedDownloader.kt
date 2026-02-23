package com.example.downloader

import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.RandomAccessFile
import kotlin.math.min

class SegmentedDownloader(private val client: OkHttpClient = OkHttpClient()) {

    // callback(downloaded, total, progressPercent)
    @Throws(Exception::class)
    fun download(url: String, destPath: String, progressCb: (Long, Long, Int) -> Unit) {
        // Synchronous simplified implementation for demo only
        val head = Request.Builder().url(url).head().build()
        client.newCall(head).execute().use { resp ->
            if (!resp.isSuccessful) throw Exception("HEAD failed: ${resp.code}")
            val length = resp.header("Content-Length")?.toLong() ?: throw Exception("No content-length")
            val acceptRanges = resp.header("Accept-Ranges") ?: "none"
            val supportsRanges = acceptRanges != "none"
            if (!supportsRanges) {
                // single-threaded fallback
                singleDownload(url, destPath) { downloaded ->
                    val progress = ((downloaded * 100) / length).toInt()
                    progressCb(downloaded, length, progress)
                }
                return
            }

            val segmentCount = 4
            val segSize = length / segmentCount
            val raf = RandomAccessFile(destPath, "rw")
            raf.setLength(length)
            raf.close()

            val threads = mutableListOf<Thread>()
            val downloadedShared = LongArray(1)

            for (i in 0 until segmentCount) {
                val start = i * segSize
                val end = if (i == segmentCount - 1) length - 1 else ((i + 1) * segSize) - 1
                val t = Thread {
                    val req = Request.Builder().url(url).addHeader("Range", "bytes=$start-$end").build()
                    client.newCall(req).execute().use { r ->
                        if (!r.isSuccessful) throw Exception("Segment failed ${r.code}")
                        val input = r.body!!.byteStream()
                        RandomAccessFile(destPath, "rw").use { rfile ->
                            rfile.seek(start)
                            val buffer = ByteArray(8 * 1024)
                            var read: Int
                            var written = 0L
                            while (input.read(buffer).also { read = it } != -1) {
                                rfile.write(buffer, 0, read)
                                written += read
                                synchronized(downloadedShared) { downloadedShared[0] += read }
                                val prog = ((downloadedShared[0] * 100) / length).toInt()
                                progressCb(downloadedShared[0], length, prog)
                            }
                        }
                    }
                }
                threads.add(t)
                t.start()
            }

            threads.forEach { it.join() }
        }
    }

    private fun singleDownload(url: String, destPath: String, progressSimple: (Long) -> Unit) {
        val req = Request.Builder().url(url).build()
        client.newCall(req).execute().use { r ->
            if (!r.isSuccessful) throw Exception("Download failed ${r.code}")
            val len = r.body?.contentLength() ?: -1
            val input = r.body!!.byteStream()
            RandomAccessFile(destPath, "rw").use { raf ->
                val buffer = ByteArray(8 * 1024)
                var read: Int
                var total = 0L
                while (input.read(buffer).also { read = it } != -1) {
                    raf.write(buffer, 0, read)
                    total += read
                    progressSimple(total)
                }
            }
        }
    }
}
