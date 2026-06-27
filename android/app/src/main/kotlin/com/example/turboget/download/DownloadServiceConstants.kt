package com.example.turboget.download

/**
 * Download Service Constants
 */
object DownloadServiceConstants {
    const val CHANNEL_ID = "turbo_download_channel"
    const val CHANNEL_NAME = "Download Progress"
    const val CHANNEL_DESCRIPTION = "Shows download progress notifications"
    
    const val NOTIFICATION_ID = 1001
    const val FOREGROUND_NOTIFICATION_ID = 1002
    
    const val ACTION_START = "com.example.turboget.action.START_DOWNLOAD"
    const val ACTION_PAUSE = "com.example.turboget.action.PAUSE_DOWNLOAD"
    const val ACTION_RESUME = "com.example.turboget.action.RESUME_DOWNLOAD"
    const val ACTION_CANCEL = "com.example.turboget.action.CANCEL_DOWNLOAD"
    
    const val EXTRA_URL = "url"
    const val EXTRA_FILE_NAME = "file_name"
    const val EXTRA_SAVE_PATH = "save_path"
    const val EXTRA_DOWNLOAD_ID = "download_id"
}
