package com.example.downloader

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives Pause / Resume / Cancel taps from the download progress
 * notification and forwards them to the running [DownloaderPlugin].
 *
 * The plugin maintains a static handle table so it can react to these
 * broadcasts even if the Flutter UI isn't currently in the foreground.
 */
class DownloadActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(DownloadForegroundService.EXTRA_ID) ?: return
        when (intent.action) {
            "com.example.downloader.action.pause" -> DownloaderPlugin.handleNotificationAction(id, "pause")
            "com.example.downloader.action.resume" -> DownloaderPlugin.handleNotificationAction(id, "resume")
            "com.example.downloader.action.cancel" -> DownloaderPlugin.handleNotificationAction(id, "cancel")
        }
    }
}
