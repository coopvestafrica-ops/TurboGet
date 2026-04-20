package com.example.downloader

import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.io.RandomAccessFile

/**
 * Segmented HTTP range downloader.
 *
 * Callers construct a [Control] object and pass it alongside the usual
 * arguments; setting `paused = true` pauses every segment worker at the
 * next loop iteration and `cancelled = true` tears the download down
 * cooperatively.
 */
class SegmentedDownloader(private val client: OkHttpClient = OkHttpClient()) {

    class Control {
        @Volatile var paused: Boolean = false
        @Volatile var cancelled: Boolean = false
        /** Used so threads can wait/notify on pause/cancel transitions. */
        val lock: Any = Any()
    }

    @Throws(Exception::class)
    fun download(
        url: String,
        destPath: String,
        control: Control = Control(),
        progressCb: (Long, Long, Int) -> Unit,
    ) {
        val head = Request.Builder().url(url).head().build()
        client.newCall(head).execute().use { resp ->
            if (!resp.isSuccessful) throw IOException("HEAD failed: ${resp.code}")
            val length = resp.header("Content-Length")?.toLong()
                ?: throw IOException("No content-length header")
            val acceptRanges = resp.header("Accept-Ranges") ?: "none"
            val supportsRanges = acceptRanges != "none"

            if (!supportsRanges) {
                singleDownload(url, destPath, control) { downloaded ->
                    val progress = if (length > 0) ((downloaded * 100) / length).toInt() else 0
                    progressCb(downloaded, length, progress)
                }
                return
            }

            val segmentCount = 4
            val segSize = length / segmentCount

            // Reserve the full output size up front so segment workers can
            // seek into their slice safely.
            RandomAccessFile(destPath, "rw").use { it.setLength(length) }

            val threads = mutableListOf<Thread>()
            val downloadedShared = LongArray(1)
            val failures = mutableListOf<Throwable>()

            for (i in 0 until segmentCount) {
                val start = i * segSize
                val end = if (i == segmentCount - 1) length - 1 else ((i + 1) * segSize) - 1
                val t = Thread({
                    try {
                        downloadSegment(url, destPath, start, end, control) { delta ->
                            synchronized(downloadedShared) { downloadedShared[0] += delta }
                            val prog = ((downloadedShared[0] * 100) / length).toInt()
                            progressCb(downloadedShared[0], length, prog)
                        }
                    } catch (e: Throwable) {
                        synchronized(failures) { failures.add(e) }
                    }
                }, "segdl-$i")
                threads.add(t)
                t.start()
            }

            threads.forEach { it.join() }

            if (control.cancelled) return
            if (failures.isNotEmpty()) {
                throw IOException("Segment download failed: ${failures.first().message}", failures.first())
            }
        }
    }

    private fun downloadSegment(
        url: String,
        destPath: String,
        start: Long,
        end: Long,
        control: Control,
        onBytes: (Long) -> Unit,
    ) {
        val req = Request.Builder().url(url).addHeader("Range", "bytes=$start-$end").build()
        client.newCall(req).execute().use { r ->
            if (!r.isSuccessful) throw IOException("Segment failed ${r.code}")
            val input = r.body?.byteStream() ?: throw IOException("Empty segment body")
            RandomAccessFile(destPath, "rw").use { rfile ->
                rfile.seek(start)
                val buffer = ByteArray(8 * 1024)
                while (true) {
                    if (control.cancelled) return
                    awaitResume(control)
                    val read = input.read(buffer)
                    if (read == -1) break
                    rfile.write(buffer, 0, read)
                    onBytes(read.toLong())
                }
            }
        }
    }

    private fun singleDownload(
        url: String,
        destPath: String,
        control: Control,
        progressSimple: (Long) -> Unit,
    ) {
        val req = Request.Builder().url(url).build()
        client.newCall(req).execute().use { r ->
            if (!r.isSuccessful) throw IOException("Download failed ${r.code}")
            val input = r.body?.byteStream() ?: throw IOException("Empty response body")
            RandomAccessFile(destPath, "rw").use { raf ->
                val buffer = ByteArray(8 * 1024)
                var total = 0L
                while (true) {
                    if (control.cancelled) return
                    awaitResume(control)
                    val read = input.read(buffer)
                    if (read == -1) break
                    raf.write(buffer, 0, read)
                    total += read
                    progressSimple(total)
                }
            }
        }
    }

    private fun awaitResume(control: Control) {
        while (control.paused && !control.cancelled) {
            synchronized(control.lock) {
                if (control.paused && !control.cancelled) {
                    try {
                        (control.lock as Object).wait(250)
                    } catch (_: InterruptedException) {
                        Thread.currentThread().interrupt()
                        return
                    }
                }
            }
        }
    }
}
