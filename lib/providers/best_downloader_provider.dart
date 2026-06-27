import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/best_downloader_service.dart';

/// Provider for BestDownloaderService
final bestDownloaderProvider = Provider<BestDownloaderService>((ref) {
  return BestDownloaderService();
});

/// Provider for all downloads
final allDownloadsProvider = StateNotifierProvider<DownloadsNotifier, List<PersistedDownload>>((ref) {
  final downloader = ref.watch(bestDownloaderProvider);
  return DownloadsNotifier(downloader);
});

/// Provider for active downloads
final activeDownloadsProvider = Provider<List<PersistedDownload>>((ref) {
  final downloads = ref.watch(allDownloadsProvider);
  return downloads.where((d) => d.status == DownloadStatus.downloading).toList();
});

/// Provider for paused downloads
final pausedDownloadsProvider = Provider<List<PersistedDownload>>((ref) {
  final downloads = ref.watch(allDownloadsProvider);
  return downloads.where((d) => d.status == DownloadStatus.paused).toList();
});

/// Provider for completed downloads
final completedDownloadsProvider = Provider<List<PersistedDownload>>((ref) {
  final downloads = ref.watch(allDownloadsProvider);
  return downloads.where((d) => d.status == DownloadStatus.completed).toList();
});

/// Provider for download statistics
final downloadStatsProvider = Provider<DownloadStats>((ref) {
  final downloads = ref.watch(allDownloadsProvider);
  
  final completed = downloads.where((d) => d.status == DownloadStatus.completed).toList();
  final today = DateTime.now();
  final todayCount = completed.where((d) {
    final date = DateTime.fromMillisecondsSinceEpoch(d.completedAt ?? d.createdAt);
    return date.year == today.year && date.month == today.month && date.day == today.day;
  }).length;
  
  final totalSize = completed.fold<int>(0, (sum, d) => sum + d.totalSize);
  final totalSpeed = downloads
      .where((d) => d.status == DownloadStatus.downloading)
      .fold<double>(0, (sum, d) => sum + d.speed);

  return DownloadStats(
    totalDownloads: completed.length,
    todayDownloads: todayCount,
    activeDownloads: downloads.where((d) => d.status == DownloadStatus.downloading).length,
    pausedDownloads: downloads.where((d) => d.status == DownloadStatus.paused).length,
    totalSize: totalSize,
    currentSpeed: totalSpeed.round(),
  );
});

/// Downloads state notifier
class DownloadsNotifier extends StateNotifier<List<PersistedDownload>> {
  final BestDownloaderService _downloader;

  DownloadsNotifier(this._downloader) : super([]) {
    _init();
  }

  Future<void> _init() async {
    await _downloader.initialize();
    
    // Set up callbacks
    _downloader.onProgress = (download) {
      _updateDownload(download);
    };
    
    _downloader.onComplete = (download) {
      _updateDownload(download);
    };
    
    _downloader.onError = (download, error) {
      _updateDownload(download);
    };

    // Resume all paused downloads
    await _downloader.resumeAllPausedDownloads();
    
    // Load all downloads
    state = _downloader.getAllDownloads();
  }

  void _updateDownload(PersistedDownload download) {
    state = _downloader.getAllDownloads();
  }

  Future<void> startDownload(String url, {String? filename}) async {
    await _downloader.startDownload(url, filename: filename);
    state = _downloader.getAllDownloads();
  }

  Future<void> pauseDownload(String id) async {
    await _downloader.pauseDownload(id);
    state = _downloader.getAllDownloads();
  }

  Future<void> resumeDownload(String id) async {
    await _downloader.resumeDownload(id);
    state = _downloader.getAllDownloads();
  }

  Future<void> cancelDownload(String id) async {
    await _downloader.cancelDownload(id);
    state = _downloader.getAllDownloads();
  }

  Future<void> deleteDownload(String id) async {
    await _downloader.deleteDownload(id);
    state = _downloader.getAllDownloads();
  }

  Future<void> refresh() async {
    state = _downloader.getAllDownloads();
  }
}

/// Download statistics model
class DownloadStats {
  final int totalDownloads;
  final int todayDownloads;
  final int activeDownloads;
  final int pausedDownloads;
  final int totalSize;
  final int currentSpeed;

  DownloadStats({
    required this.totalDownloads,
    required this.todayDownloads,
    required this.activeDownloads,
    required this.pausedDownloads,
    required this.totalSize,
    required this.currentSpeed,
  });

  String get formattedTotalSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    if (totalSize < 1024 * 1024 * 1024) return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedSpeed {
    if (currentSpeed < 1024) return '$currentSpeed B/s';
    if (currentSpeed < 1024 * 1024) return '${(currentSpeed / 1024).toStringAsFixed(1)} KB/s';
    return '${(currentSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}