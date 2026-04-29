package com.example.downloader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps the download process alive and renders
 * a sticky progress notification with Pause / Resume / Cancel actions.
 *
 * The plugin sends `update`/`stop` intents to this service to drive the
 * notification UI; tap-actions on the notification arrive at
 * [DownloadActionReceiver] which forwards them back to the plugin.
 */
class DownloadForegroundService : Service() {

    companion object {
        const val ACTION_UPDATE = "com.example.downloader.UPDATE"
        const val ACTION_STOP = "com.example.downloader.STOP"
        const val EXTRA_ID = "id"
        const val EXTRA_FILENAME = "filename"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_DOWNLOADED = "downloaded"
        const val EXTRA_TOTAL = "total"
        const val EXTRA_STATUS = "status"

        const val CHANNEL_ID = "turboget_downloads"
        const val CHANNEL_NAME = "Downloads"
        const val ROOT_NOTIFICATION_ID = 0xD0001 // 851969 — unique-ish

        fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(CHANNEL_ID) != null) return
            val ch = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "TurboGet download progress"
                setShowBadge(false)
            }
            mgr.createNotificationChannel(ch)
        }
    }

    private val perDownload = HashMap<String, Int>()
    private var nextId: Int = ROOT_NOTIFICATION_ID + 1

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel(this)
        // Promote ourselves with a placeholder notification so the OS
        // doesn't kill us before any download has reported progress.
        startForeground(ROOT_NOTIFICATION_ID, buildRootNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE -> handleUpdate(intent)
            ACTION_STOP -> handleStop(intent)
        }
        return START_STICKY
    }

    private fun handleUpdate(intent: Intent) {
        val id = intent.getStringExtra(EXTRA_ID) ?: return
        val filename = intent.getStringExtra(EXTRA_FILENAME) ?: id
        val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
        val status = intent.getStringExtra(EXTRA_STATUS) ?: "downloading"
        val downloaded = intent.getLongExtra(EXTRA_DOWNLOADED, 0L)
        val total = intent.getLongExtra(EXTRA_TOTAL, 0L)

        val nid = perDownload.getOrPut(id) { nextId++ }
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        mgr.notify(nid, buildDownloadNotification(id, filename, progress, status, downloaded, total))

        if (status == "completed" || status == "failed" || status == "cancelled") {
            // Auto-dismiss after a short while so the user can read it.
            mgr.cancel(nid)
            perDownload.remove(id)
            if (perDownload.isEmpty()) {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
    }

    private fun handleStop(intent: Intent) {
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        for ((_, nid) in perDownload) mgr.cancel(nid)
        perDownload.clear()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildRootNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("TurboGet")
            .setContentText("Preparing downloads…")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun buildDownloadNotification(
        id: String,
        filename: String,
        progress: Int,
        status: String,
        downloaded: Long,
        total: Long,
    ): Notification {
        val pauseIntent = downloadActionIntent(id, "pause")
        val resumeIntent = downloadActionIntent(id, "resume")
        val cancelIntent = downloadActionIntent(id, "cancel")

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(filename)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOnlyAlertOnce(true)
            .setOngoing(status == "downloading" || status == "paused")
            .setPriority(NotificationCompat.PRIORITY_LOW)

        when (status) {
            "completed" -> {
                builder.setContentText("Download complete")
                    .setSmallIcon(android.R.drawable.stat_sys_download_done)
                    .setProgress(0, 0, false)
                    .setOngoing(false)
            }
            "failed" -> {
                builder.setContentText("Download failed")
                    .setSmallIcon(android.R.drawable.stat_notify_error)
                    .setProgress(0, 0, false)
                    .setOngoing(false)
            }
            "cancelled" -> {
                builder.setContentText("Cancelled")
                    .setProgress(0, 0, false)
                    .setOngoing(false)
            }
            "paused" -> {
                builder.setContentText("Paused — ${humanBytes(downloaded)} / ${humanBytes(total)}")
                    .setProgress(100, progress, false)
                    .addAction(0, "Resume", resumeIntent)
                    .addAction(0, "Cancel", cancelIntent)
            }
            else -> {
                builder.setContentText("$progress% — ${humanBytes(downloaded)} / ${humanBytes(total)}")
                    .setProgress(100, progress, progress <= 0)
                    .addAction(0, "Pause", pauseIntent)
                    .addAction(0, "Cancel", cancelIntent)
            }
        }

        return builder.build()
    }

    private fun downloadActionIntent(id: String, action: String): PendingIntent {
        val intent = Intent(this, DownloadActionReceiver::class.java).apply {
            this.action = "com.example.downloader.action.$action"
            putExtra(EXTRA_ID, id)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(
            this,
            (id + action).hashCode(),
            intent,
            flags,
        )
    }

    private fun humanBytes(b: Long): String {
        if (b <= 0) return "—"
        if (b < 1024) return "${b}B"
        if (b < 1024 * 1024) return "${b / 1024}KB"
        if (b < 1024L * 1024L * 1024L) return "%.1fMB".format(b.toDouble() / (1024.0 * 1024.0))
        return "%.2fGB".format(b.toDouble() / (1024.0 * 1024.0 * 1024.0))
    }
}
