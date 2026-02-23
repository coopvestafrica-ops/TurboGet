import 'dart:async';
import 'dart:collection';
import '../models/download_item.dart';
import '../models/download_state.dart';
import 'database_service.dart';
import 'turbo_downloader.dart';
import 'package:flutter/foundation.dart';

class ConcurrentDownloadManager {
  static final ConcurrentDownloadManager _instance = ConcurrentDownloadManager._internal();
  factory ConcurrentDownloadManager() => _instance;
  ConcurrentDownloadManager._internal();

  static const int maxConcurrentDownloads = 50;
  
  final DatabaseService _db = DatabaseService();
  final TurboDownloader _turboDownloader = TurboDownloader();
  final Queue<DownloadItem> _downloadQueue = Queue<DownloadItem>();
  final Map<String, StreamSubscription<DownloadProgress>> _activeDownloads = {};
  final _downloadController = StreamController<DownloadItem>.broadcast();
  final Map<String, Completer<void>> _downloadCompleters = {};

  Stream<DownloadItem> get downloadUpdates => _downloadController.stream;

  Future<void> addDownload(DownloadItem item) async {
    // First save to database
    await _db.insertDownload(item.toMap());
    
    // Add to queue and process
    _downloadQueue.add(item);
    _processQueue();
    
    // Notify listeners
    _downloadController.add(item);
  }

  Future<void> _processQueue() async {
  // Count active downloads (length accessed directly where needed)
    
    // Process queue if we have capacity
    while (_downloadQueue.isNotEmpty && 
           _activeDownloads.length < maxConcurrentDownloads) {
      final item = _downloadQueue.removeFirst();
      await _startDownload(item);
    }
  }

  Future<void> _startDownload(DownloadItem item) async {
    try {
      // Create a completer for this download
      final completer = Completer<void>();
      _downloadCompleters[item.id] = completer;

      // Update status to downloading
      item.status = 'downloading';
      await _db.updateDownload(item.id, {'status': 'downloading'});
      _downloadController.add(item);

      // Get existing download state if any
      final existingState = await _getDownloadState(item.id);
      
    // Start (or resume if resumeState provided) download
    final progressStream = _turboDownloader.downloadFile(item, resumeState: existingState);

      _activeDownloads[item.id] = progressStream.listen(
        (progress) async {
          // Save progress periodically
          if (progress.downloadedBytes % (1024 * 1024) == 0) { // Every 1MB
            await _saveDownloadState(item.id, progress);
          }

          // Update download progress
          final Map<String, dynamic> updates = {
            'downloaded_size': progress.downloadedBytes,
            'total_size': progress.totalBytes,
            'progress': (progress.progress * 100).round(),
          };

          if (progress.isComplete) {
            updates['status'] = 'completed';
            await _clearDownloadState(item.id);
          }

          await _db.updateDownload(item.id, updates);
          
          final updatedItem = DownloadItem.fromMap({
            ...item.toMap(),
            ...updates,
          });
          _downloadController.add(updatedItem);

          if (progress.isComplete) {
            _activeDownloads.remove(item.id);
            _downloadCompleters.remove(item.id)?.complete();
            _processQueue();
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
          _downloadCompleters.remove(item.id)?.completeError(error);
          _processQueue();
        },
      );
    } catch (e) {
      debugPrint('Failed to start download: $e');
      await _db.updateDownload(item.id, {
        'status': 'failed',
        'error': e.toString(),
      });
      _activeDownloads.remove(item.id);
      _downloadCompleters.remove(item.id)?.completeError(e);
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
      _downloadQueue.addFirst(item);
      _processQueue();
    }
  }

  Future<void> cancelDownload(String id) async {
    await pauseDownload(id);
    await _clearDownloadState(id);
    await _db.deleteDownload(id);
  }

  Future<void> _saveDownloadState(String id, DownloadProgress progress) async {
    final state = DownloadState(
      id: id,
      url: (await _db.getDownload(id))!['url'],
      filename: (await _db.getDownload(id))!['filename'],
      totalSize: progress.totalBytes,
      segments: _turboDownloader.getSegmentStates(id),
      lastUpdated: DateTime.now(),
    );

    await _db.updateDownload(id, {
      'resume_data': state.toJson(),
    });
  }

  Future<DownloadState?> _getDownloadState(String id) async {
    final download = await _db.getDownload(id);
    if (download != null && download['resume_data'] != null) {
      return DownloadState.fromJson(download['resume_data']);
    }
    return null;
  }

  Future<void> _clearDownloadState(String id) async {
    await _db.updateDownload(id, {
      'resume_data': null,
    });
  }

  void dispose() {
    for (var sub in _activeDownloads.values) {
      sub.cancel();
    }
    _activeDownloads.clear();
    _downloadController.close();
  }
}
