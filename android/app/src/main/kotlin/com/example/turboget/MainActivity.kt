package com.example.turboget

import android.content.Intent
import android.os.Bundle
import com.example.downloader.DownloaderPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val SHARE_CHANNEL = "com.example.turboget/share"

    private var shareChannel: MethodChannel? = null
    // URL received from an Intent before the Flutter channel was ready.
    private var pendingSharedUrl: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register our native segmented-downloader plugin so the Dart
        // MethodChannel 'com.example.downloader/methods' actually has a
        // handler. Without this every startDownload call fails with
        // MissingPluginException.
        flutterEngine.plugins.add(DownloaderPlugin())

        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedUrl" -> {
                        result.success(pendingSharedUrl)
                        pendingSharedUrl = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val url = when (intent.action) {
            Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
            Intent.ACTION_VIEW -> intent.dataString ?: intent.data?.toString()
            else -> null
        }?.trim()
        if (url.isNullOrEmpty()) return

        // Extract the first http(s) URL if the shared text contains prose.
        val match = Regex("https?://\\S+").find(url)
        val resolved = match?.value ?: if (url.startsWith("http")) url else null
        if (resolved.isNullOrEmpty()) return

        val channel = shareChannel
        if (channel != null) {
            channel.invokeMethod("sharedUrl", resolved)
        } else {
            pendingSharedUrl = resolved
        }
    }
}
