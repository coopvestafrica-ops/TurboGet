import 'dart:async';
import 'package:flutter/material.dart';
import '../models/download_item.dart';
import 'database_service.dart';
import 'turbo_downloader.dart';
import 'platform_analyzer.dart';

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final DatabaseService _db = DatabaseService();
  final TurboDownloader _turboDownloader = TurboDownloader();
  final PlatformAnalyzer _platformAnalyzer = PlatformAnalyzer();
  final Map<String, StreamSubscription> _activeDownloads = {};
  final _downloadController = StreamController<DownloadItem>.broadcast();

  Stream<DownloadItem> get downloadUpdates => _downloadController.stream;

  Future<void> addDownload(String url, {String? filename, VideoQuality? quality}) async {
    try {
      // First analyze the platform and get metadata
      final platform = await _platformAnalyzer.detectPlatform(url);
      final metadata = await _platformAnalyzer.getVideoMetadata(url);
      
      // If no filename provided, use the title from metadata
      filename ??= _sanitizeFilename(metadata['title'] ?? url.split('/').last.split('?').first);
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // For video platforms, get available qualities if not specified
      List<VideoQuality>? qualities;
      if (platform == PlatformType.youtube || 
          platform == PlatformType.vimeo || 
          platform == PlatformType.dailymotion) {
        qualities = await _platformAnalyzer.getVideoQualities(url);
      }

      // If qualities are available but none selected, use the best quality
      if (qualities != null && qualities.isNotEmpty && quality == null) {
        quality = qualities.first; // Usually the best quality
      }

      final download = DownloadItem(
        id: id,
        url: quality?.url ?? url,
        filename: filename,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        status: 'queued',
        metadata: {
          'platform': platform.toString(),
          'title': metadata['title'],
          'author': metadata['author'],
          'thumbnail': metadata['thumbnailUrl'],
          'qualities': qualities?.map((q) => {
            'quality': q.quality,
            'format': q.format,
            'url': q.url,
          }).toList(),
        },
      );

      await _db.insertDownload(download.toMap());
      _downloadController.add(download);

      // Start download if we have capacity
      _processQueue();
    } catch (e) {
      debugPrint('Failed to add download: $e');
      rethrow;
    }
  }

  String _sanitizeFilename(String filename) {
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\w\-_\.]'), '');
  }

  Future<void> _processQueue() async {
    if (_activeDownloads.length >= 3) return; // Max concurrent downloads

    final queued = await _db.getQueuedDownloads();
    for (var download in queued) {
      if (_activeDownloads.length >= 3) break;

      final item = DownloadItem.fromMap(download);
      _startDownload(item);
    }
  }

  void _startDownload(DownloadItem item) async {
    try {
      // Update status to downloading
      item.status = 'downloading';
      await _db.updateDownload(item.id, {'status': 'downloading'});
      _downloadController.add(item);

      // Start turbo download
      final progressStream = _turboDownloader.downloadFile(item);
      _activeDownloads[item.id] = progressStream.listen(
        (progress) async {
          // Update download progress
          final updates = {
            'downloaded_size': progress.downloadedBytes,
            'total_size': progress.totalBytes,
            'progress': (progress.progress * 100).round(),
          };

          if (progress.isComplete) {
            updates['status'] = 2; // Assuming 2 represents 'completed' status as int
          }

          await _db.updateDownload(item.id, updates);
          
          final updatedItem = DownloadItem.fromMap({
            ...item.toMap(),
            ...updates,
          });
          _downloadController.add(updatedItem);

          if (progress.isComplete) {
            _activeDownloads.remove(item.id);
            _processQueue(); // Start next download
          }
        },
        onError: (error) async {
          debugPrint('Download error: $error');
          await _db.updateDownload(item.id, {
            'status': 'failed',
            'error': error.toString(),
          });

          final failedItem = DownloadItem.fromMap({
            ...item.toMap(),
            'status': 'failed',
            'error': error.toString(),
          });
          _downloadController.add(failedItem);

          _activeDownloads.remove(item.id);
          _processQueue(); // Start next download
        },
      );
    } catch (e) {
      debugPrint('Failed to start download: $e');
      await _db.updateDownload(item.id, {
        'status': 'failed',
        'error': e.toString(),
      });
      _activeDownloads.remove(item.id);
      _processQueue();
    }
  }

  Future<void> pauseDownload(String id) async {
    final sub = _activeDownloads[id];
    if (sub != null) {
      await sub.cancel();
      _activeDownloads.remove(id);
      _turboDownloader.cancelDownload(id);
      
      await _db.updateDownload(id, {'status': 'paused'});
      final download = await _db.getDownload(id);
      if (download != null) {
        _downloadController.add(DownloadItem.fromMap(download));
      }
    }
  }

  Future<void> resumeDownload(String id) async {
    final download = await _db.getDownload(id);
    if (download != null && download['status'] == 'paused') {
      final item = DownloadItem.fromMap(download);
      _startDownload(item);
    }
  }

  Future<void> cancelDownload(String id) async {
    await pauseDownload(id);
    await _db.deleteDownload(id);
  }

  Future<List<DownloadItem>> getAllDownloads() async {
    final downloads = await _db.getAllDownloads();
    return downloads.map((d) => DownloadItem.fromMap(d)).toList();
  }

  void dispose() {
    for (var sub in _activeDownloads.values) {
      sub.cancel();
    }
    _activeDownloads.clear();
    _downloadController.close();
  }
}
