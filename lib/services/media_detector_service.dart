import 'dart:async';
import 'package:flutter/foundation.dart';
import 'platform_analyzer.dart';
import 'download_manager.dart';

/// Lightweight MediaDetectorService stub
///
/// The project previously used `system_alert_window` APIs that don't match the
/// pinned package version. To unblock analysis and builds, this service
/// provides a minimal, safe implementation that detects URLs and notifies the
/// download manager. You can re-enable rich overlays once the package API is
/// aligned.
class MediaDetectorService {
  static final MediaDetectorService _instance = MediaDetectorService._internal();
  factory MediaDetectorService() => _instance;
  MediaDetectorService._internal();

  final PlatformAnalyzer _platformAnalyzer = PlatformAnalyzer();
  final DownloadManager _downloadManager = DownloadManager();
  Timer? _debounceTimer;
  // overlay visibility state removed: overlays are not shown in this stub

  /// Initialize the detector. Previously this requested overlay permissions —
  /// the current minimal implementation does no-op.
  Future<void> initialize() async {
    // No-op: permissions/overlay code removed to maintain compatibility with
    // the pinned `system_alert_window` version. Re-add if you upgrade the package.
  }

  /// Detect URLs and (for now) log and notify the download manager.
  Future<void> detectAndShowMedia(String text) async {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final urlRegex = RegExp(
        r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      );

      final matches = urlRegex.allMatches(text);
      for (var match in matches) {
        final url = match.group(0)!;
        try {
          final platform = await _platformAnalyzer.detectPlatform(url);
          if (platform != PlatformType.general) {
            final metadata = await _platformAnalyzer.getVideoMetadata(url);
            debugPrint('Media detected: $url title=${metadata['title'] ?? ''}');
            // Minimal behavior: add to download queue via DownloadManager.
            // DownloadManager will re-run platform analysis as needed.
            await _downloadManager.addDownload(url);
            return;
          }
        } catch (e) {
          debugPrint('Error detecting media: $e');
        }
      }
    });
  }

  // _handleDetectedMedia removed: overlay interactions are not part of this stub

  void dispose() {
    _debounceTimer?.cancel();
  }
}
