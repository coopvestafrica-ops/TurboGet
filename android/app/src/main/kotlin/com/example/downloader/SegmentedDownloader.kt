package com.example.downloader

import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.security.MessageDigest

/**
 * Segmented HTTP range downloader with cooperative pause/resume/cancel,
 * exponential-backoff retry, partial-file resume via a `.tg.json`
 * sidecar, optional bandwidth throttling, and SHA-256 verification.
 */
class SegmentedDownloader(private val client: OkHttpClient = OkHttpClient()) {

    class Control {
        @Volatile var paused: Boolean = false
        @Volatile var cancelled: Boolean = false
        /** Bytes per second cap, <= 0 == unlimited. */
        @Volatile var bytesPerSecond: Long = 0
        /** Used so threads can wait/notify on pause/cancel transitions. */
        val lock: Any = Any()
    }

    private data class SegmentState(
        val start: Long,
        val end: Long,
        @Volatile var downloaded: Long,
    )

    @Throws(Exception::class)
    fun download(
        url: String,
        destPath: String,
        control: Control = Control(),
        expectedSha256: String? = null,
        progressCb: (Long, Long, Int) -> Unit,
    ) {
        val sidecarPath = "$destPath.tg.json"
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
                if (!control.cancelled) {
                    verifyChecksum(destPath, expectedSha256)
                }
                return
            }

            val segmentCount = 4
            val segSize = length / segmentCount

            // Try to resume from a previous run if the sidecar matches.
            val resumed = readSidecar(sidecarPath, url, length)
            val segments: MutableList<SegmentState> = if (resumed != null) {
                resumed.toMutableList()
            } else {
                MutableList(segmentCount) { i ->
                    val start = i * segSize
                    val end = if (i == segmentCount - 1) length - 1 else ((i + 1) * segSize) - 1
                    SegmentState(start, end, 0L)
                }
            }

            // Reserve the full output size up front so segment workers can
            // seek into their slice safely. Skip if the file is already
            // the right size (resume case).
            val destFile = File(destPath)
            if (!destFile.exists() || destFile.length() != length) {
                RandomAccessFile(destPath, "rw").use { it.setLength(length) }
            }

            // Initial progress emission so the UI shows resume offset.
            val initialBytes = segments.sumOf { it.downloaded }
            if (initialBytes > 0) {
                val prog = ((initialBytes * 100) / length).toInt()
                progressCb(initialBytes, length, prog)
            }

            val threads = mutableListOf<Thread>()
            val downloadedShared = LongArray(1).also { it[0] = initialBytes }
            val failures = mutableListOf<Throwable>()
            val sidecarSaver = SidecarSaver(sidecarPath, url, length, segments)
            val throttle = Throttle(control)

            for (seg in segments) {
                if (seg.downloaded >= (seg.end - seg.start + 1)) continue
                val t = Thread({
                    try {
                        downloadSegmentWithRetry(url, destPath, seg, control, throttle) { delta ->
                            synchronized(downloadedShared) { downloadedShared[0] += delta }
                            val prog = ((downloadedShared[0] * 100) / length).toInt()
                            progressCb(downloadedShared[0], length, prog)
                            sidecarSaver.maybeSave()
                        }
                    } catch (e: Throwable) {
                        synchronized(failures) { failures.add(e) }
                    }
                }, "segdl")
                threads.add(t)
                t.start()
            }

            threads.forEach { it.join() }
            sidecarSaver.flush()

            if (control.cancelled) return
            if (failures.isNotEmpty()) {
                throw IOException("Segment download failed: ${failures.first().message}", failures.first())
            }

            // Success — verify checksum and clean up the sidecar.
            verifyChecksum(destPath, expectedSha256)
            File(sidecarPath).delete()
        }
    }

    private fun downloadSegmentWithRetry(
        url: String,
        destPath: String,
        seg: SegmentState,
        control: Control,
        throttle: Throttle,
        onBytes: (Long) -> Unit,
    ) {
        val maxAttempts = 5
        var attempt = 0
        while (true) {
            try {
                downloadSegment(url, destPath, seg, control, throttle, onBytes)
                return
            } catch (e: IOException) {
                if (control.cancelled) return
                attempt++
                if (attempt >= maxAttempts) throw e
                val backoff = (1_000L shl (attempt - 1)).coerceAtMost(16_000L)
                Thread.sleep(backoff)
            }
        }
    }

    private fun downloadSegment(
        url: String,
        destPath: String,
        seg: SegmentState,
        control: Control,
        throttle: Throttle,
        onBytes: (Long) -> Unit,
    ) {
        val rangeStart = seg.start + seg.downloaded
        val req = Request.Builder()
            .url(url)
            .addHeader("Range", "bytes=$rangeStart-${seg.end}")
            .build()
        client.newCall(req).execute().use { r ->
            if (!r.isSuccessful) throw IOException("Segment failed ${r.code}")
            val input = r.body?.byteStream() ?: throw IOException("Empty segment body")
            RandomAccessFile(destPath, "rw").use { rfile ->
                rfile.seek(rangeStart)
                val buffer = ByteArray(8 * 1024)
                while (true) {
                    if (control.cancelled) return
                    awaitResume(control)
                    val read = input.read(buffer)
                    if (read == -1) break
                    rfile.write(buffer, 0, read)
                    seg.downloaded += read
                    onBytes(read.toLong())
                    throttle.consume(read.toLong())
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
        val maxAttempts = 5
        var attempt = 0
        while (true) {
            try {
                client.newCall(req).execute().use { r ->
                    if (!r.isSuccessful) throw IOException("Download failed ${r.code}")
                    val input = r.body?.byteStream() ?: throw IOException("Empty response body")
                    RandomAccessFile(destPath, "rw").use { raf ->
                        val buffer = ByteArray(8 * 1024)
                        var total = 0L
                        val throttle = Throttle(control)
                        while (true) {
                            if (control.cancelled) return
                            awaitResume(control)
                            val read = input.read(buffer)
                            if (read == -1) break
                            raf.write(buffer, 0, read)
                            total += read
                            progressSimple(total)
                            throttle.consume(read.toLong())
                        }
                    }
                }
                return
            } catch (e: IOException) {
                if (control.cancelled) return
                attempt++
                if (attempt >= maxAttempts) throw e
                val backoff = (1_000L shl (attempt - 1)).coerceAtMost(16_000L)
                Thread.sleep(backoff)
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

    private fun readSidecar(
        path: String,
        url: String,
        length: Long,
    ): List<SegmentState>? {
        val f = File(path)
        if (!f.exists()) return null
        return try {
            val obj = JSONObject(f.readText())
            if (obj.optString("url") != url) return null
            if (obj.optLong("length") != length) return null
            val arr = obj.optJSONArray("segments") ?: return null
            val out = mutableListOf<SegmentState>()
            for (i in 0 until arr.length()) {
                val s = arr.getJSONObject(i)
                out.add(
                    SegmentState(
                        s.getLong("start"),
                        s.getLong("end"),
                        s.getLong("downloaded"),
                    ),
                )
            }
            out
        } catch (_: Throwable) {
            null
        }
    }

    private class SidecarSaver(
        private val path: String,
        private val url: String,
        private val length: Long,
        private val segments: List<SegmentState>,
    ) {
        @Volatile private var lastSaveAt: Long = 0
        private val lock = Any()

        fun maybeSave() {
            val now = System.currentTimeMillis()
            if (now - lastSaveAt < 1_000) return
            synchronized(lock) {
                if (now - lastSaveAt < 1_000) return
                lastSaveAt = now
                writeNow()
            }
        }

        fun flush() {
            synchronized(lock) { writeNow() }
        }

        private fun writeNow() {
            try {
                val arr = JSONArray()
                for (s in segments) {
                    arr.put(
                        JSONObject().apply {
                            put("start", s.start)
                            put("end", s.end)
                            put("downloaded", s.downloaded)
                        },
                    )
                }
                val obj = JSONObject().apply {
                    put("url", url)
                    put("length", length)
                    put("segments", arr)
                }
                File(path).writeText(obj.toString())
            } catch (_: Throwable) {
                // sidecar persistence is best-effort
            }
        }
    }

    /**
     * Token-bucket-ish throttle. With a 1s window we sleep just enough
     * to keep the moving average at-or-below `bytesPerSecond`.
     */
    private class Throttle(private val control: Control) {
        private var windowStart: Long = System.nanoTime()
        private var windowBytes: Long = 0L

        fun consume(bytes: Long) {
            val cap = control.bytesPerSecond
            if (cap <= 0) return
            windowBytes += bytes
            val now = System.nanoTime()
            val elapsedNs = now - windowStart
            if (elapsedNs >= 1_000_000_000L) {
                windowStart = now
                windowBytes = 0
                return
            }
            val expectedNs = (windowBytes.toDouble() / cap.toDouble() * 1_000_000_000.0).toLong()
            if (expectedNs > elapsedNs) {
                val sleepNs = expectedNs - elapsedNs
                try {
                    Thread.sleep(sleepNs / 1_000_000L, (sleepNs % 1_000_000L).toInt())
                } catch (_: InterruptedException) {
                    Thread.currentThread().interrupt()
                }
            }
        }
    }

    private fun verifyChecksum(path: String, expected: String?) {
        if (expected.isNullOrBlank()) return
        val md = MessageDigest.getInstance("SHA-256")
        File(path).inputStream().use { inp ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = inp.read(buffer)
                if (read == -1) break
                md.update(buffer, 0, read)
            }
        }
        val actual = md.digest().joinToString("") { "%02x".format(it) }
        if (!actual.equals(expected.trim(), ignoreCase = true)) {
            throw IOException("SHA-256 mismatch: expected $expected got $actual")
        }
    }
}
