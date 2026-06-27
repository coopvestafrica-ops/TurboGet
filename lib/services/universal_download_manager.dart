import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:path/path.dart' as p;
import '../models/download_item.dart';
import '../services/media_type_service.dart';
import '../services/logger_service.dart';

/// Download status enum
enum UniversalDownloadStatus {
  pending,
  connecting,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Progress callback for download updates
typedef DownloadProgressCallback = void Function(DownloadProgressInfo info);

/// Download progress information
class DownloadProgressInfo {
  final String id;
  final String url;
  final String filename;
  final int totalBytes;
  final int downloadedBytes;
  final double speed; // bytes per second
  final UniversalDownloadStatus status;
  final String? errorMessage;
  final String? savePath;

  const DownloadProgressInfo({
    required this.id,
    required this.url,
    required this.filename,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.speed,
    required this.status,
    this.errorMessage,
    this.savePath,
  });

  double get progressPercent => totalBytes > 0 ? (downloadedBytes / totalBytes) * 100 : 0;
  
  String get formattedProgress => '${progressPercent.toStringAsFixed(1)}%';
  
  String get formattedDownloaded => _formatBytes(downloadedBytes);
  
  String get formattedTotal => _formatBytes(totalBytes);
  
  String get formattedSpeed => '${_formatBytes(speed.round())}/s';
  
  String get formattedRemaining {
    if (speed <= 0) return 'Calculating...';
    final remaining = totalBytes - downloadedBytes;
    final seconds = remaining / speed;
    return _formatDuration(seconds.round());
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    return '${hours}h ${mins}m';
  }

  DownloadProgressInfo copyWith({
    int? totalBytes,
    int? downloadedBytes,
    double? speed,
    UniversalDownloadStatus? status,
    String? errorMessage,
    String? savePath,
  }) {
    return DownloadProgressInfo(
      id: id,
      url: url,
      filename: filename,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      speed: speed ?? this.speed,
      status: status ?? this.status,
      errorMessage: errorMessage,
      savePath: savePath ?? this.savePath,
    );
  }
}

/// Universal download manager that supports all file types
class UniversalDownloadManager {
  static final UniversalDownloadManager _instance = UniversalDownloadManager._internal();
  factory UniversalDownloadManager() => _instance;
  UniversalDownloadManager._internal();

  final LoggerService _logger = logger;
  final MediaTypeService _mediaType = mediaTypeService;
  
  final Map<String, _DownloadTask> _activeTasks = {};
  final Map<String, DownloadProgressInfo> _downloadInfo = {};
  
  String? _downloadDirectory;
  int _maxConcurrentDownloads = 3;
  bool _wifiOnly = false;

  /// Initialize the download manager
  Future<void> initialize({String? customDirectory}) async {
    if (customDirectory != null) {
      _downloadDirectory = customDirectory;
    } else {
      final dir = await getExternalStorageDirectory();
      _downloadDirectory = dir != null 
          ? '${dir.path}/TurboGet' 
          : (await getApplicationDocumentsDirectory()).path;
    }
    
    // Ensure download directory exists
    final downloadDir = Directory(_downloadDirectory!);
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    
    _logger.info('UniversalDownloadManager', 'Initialized at $_downloadDirectory');
  }

  /// Set maximum concurrent downloads
  void setMaxConcurrentDownloads(int max) {
    _maxConcurrentDownloads = max.clamp(1, 10);
  }

  /// Set Wi-Fi only mode
  void setWifiOnly(bool wifiOnly) {
    _wifiOnly = wifiOnly;
  }

  /// Start a download
  Future<DownloadProgressInfo> download(
    String url, {
    String? filename,
    String? saveDirectory,
    DownloadProgressCallback? onProgress,
    DownloadProgressCallback? onComplete,
    Function(String error)? onError,
  }) async {
    final id = _generateId(url);
    
    // Check if already downloading
    if (_activeTasks.containsKey(id)) {
      return _downloadInfo[id]!;
    }

    // Determine filename
    final resolvedFilename = filename ?? _extractFilename(url);
    final directory = saveDirectory ?? _downloadDirectory!;
    
    // Create download info
    final info = DownloadProgressInfo(
      id: id,
      url: url,
      filename: resolvedFilename,
      totalBytes: 0,
      downloadedBytes: 0,
      speed: 0,
      status: UniversalDownloadStatus.pending,
      savePath: path.join(directory, resolvedFilename),
    );
    
    _downloadInfo[id] = info;
    onProgress?.call(info);

    // Create and start task
    final task = _DownloadTask(
      url: url,
      filename: resolvedFilename,
      saveDirectory: directory,
      onProgress: (updatedInfo) {
        _downloadInfo[id] = updatedInfo;
        onProgress?.call(updatedInfo);
      },
      onComplete: (completedInfo) {
        _downloadInfo[id] = completedInfo;
        _activeTasks.remove(id);
        onComplete?.call(completedInfo);
      },
      onError: (error) {
        final errorInfo = completedInfo.copyWith(
          status: UniversalDownloadStatus.failed,
          errorMessage: error,
        );
        _downloadInfo[id] = errorInfo;
        _activeTasks.remove(id);
        onError?.call(error);
      },
    );

    _activeTasks[id] = task;
    
    // Start download asynchronously
    _startDownload(task);

    return info;
  }

  /// Download multiple files
  Future<List<DownloadProgressInfo>> downloadBatch(
    List<String> urls, {
    DownloadProgressCallback? onProgress,
    DownloadProgressCallback? onComplete,
    Function(String error)? onError,
  }) async {
    final results = <DownloadProgressInfo>[];
    
    for (final url in urls) {
      final info = await download(
        url,
        onProgress: onProgress,
        onComplete: onComplete,
        onError: onError,
      );
      results.add(info);
    }
    
    return results;
  }

  /// Pause a download
  void pause(String id) {
    final task = _activeTasks[id];
    if (task != null) {
      task.pause();
      final info = _downloadInfo[id]?.copyWith(
        status: UniversalDownloadStatus.paused,
      );
      if (info != null) {
        _downloadInfo[id] = info;
      }
    }
  }

  /// Resume a download
  void resume(String id) {
    final info = _downloadInfo[id];
    if (info != null && info.status == UniversalDownloadStatus.paused) {
      download(
        info.url,
        filename: info.filename,
        saveDirectory: path.dirname(info.savePath ?? ''),
      );
    }
  }

  /// Cancel a download
  void cancel(String id) {
    final task = _activeTasks[id];
    if (task != null) {
      task.cancel();
      _activeTasks.remove(id);
      final info = _downloadInfo[id]?.copyWith(
        status: UniversalDownloadStatus.cancelled,
      );
      if (info != null) {
        _downloadInfo[id] = info;
      }
    }
  }

  /// Cancel all downloads
  void cancelAll() {
    for (final id in _activeTasks.keys.toList()) {
      cancel(id);
    }
  }

  /// Get download info
  DownloadProgressInfo? getDownloadInfo(String id) {
    return _downloadInfo[id];
  }

  /// Get all active downloads
  List<DownloadProgressInfo> getActiveDownloads() {
    return _activeTasks.keys
        .map((id) => _downloadInfo[id])
        .whereType<DownloadProgressInfo>()
        .toList();
  }

  /// Get all downloads
  List<DownloadProgressInfo> getAllDownloads() {
    return _downloadInfo.values.toList();
  }

  /// Check if a URL is already downloaded
  Future<bool> isDownloaded(String url) async {
    final filename = _extractFilename(url);
    final filePath = path.join(_downloadDirectory!, filename);
    return File(filePath).exists();
  }

  /// Get downloaded file path
  Future<String?> getDownloadedFilePath(String url) async {
    final filename = _extractFilename(url);
    final filePath = path.join(_downloadDirectory!, filename);
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  /// Delete a downloaded file
  Future<bool> deleteDownloadedFile(String url) async {
    final filePath = await getDownloadedFilePath(url);
    if (filePath != null) {
      await File(filePath).delete();
      return true;
    }
    return false;
  }

  /// Open a downloaded file (for playback)
  Future<void> openFile(String id) async {
    final info = _downloadInfo[id];
    if (info?.savePath != null) {
      final file = File(info!.savePath!);
      if (await file.exists()) {
        // Use platform-specific method to open file
        _logger.info('UniversalDownloadManager', 'Opening file: ${info.savePath}');
      }
    }
  }

  String _generateId(String url) {
    return url.hashCode.abs().toString();
  }

  String _extractFilename(String url) {
    try {
      final uri = Uri.parse(url);
      String filename = path.basename(uri.path);
      
      // Remove query parameters from filename
      if (filename.contains('?')) {
        filename = filename.split('?').first;
      }
      
      // If no filename, generate one
      if (filename.isEmpty || !filename.contains('.')) {
        final mediaType = _mediaType.getMimeType(uri.path);
        final ext = _getExtensionFromMime(mediaType ?? 'application/octet-stream');
        filename = 'download_${DateTime.now().millisecondsSinceEpoch}$ext';
      }
      
      // Sanitize filename
      return _sanitizeFilename(filename);
    } catch (e) {
      return 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  String _getExtensionFromMime(String mimeType) {
    const mimeToExt = {
      'video/mp4': '.mp4',
      'video/x-matroska': '.mkv',
      'video/quicktime': '.mov',
      'video/x-msvideo': '.avi',
      'video/webm': '.webm',
      'audio/mpeg': '.mp3',
      'audio/wav': '.wav',
      'audio/flac': '.flac',
      'audio/ogg': '.ogg',
      'image/jpeg': '.jpg',
      'image/png': '.png',
      'image/gif': '.gif',
      'application/pdf': '.pdf',
      'application/zip': '.zip',
      'application/octet-stream': '',
    };
    return mimeToExt[mimeType] ?? '';
  }

  String _sanitizeFilename(String filename) {
    // Remove or replace invalid characters
    var sanitized = filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    
    // Ensure not empty
    if (sanitized.isEmpty) {
      sanitized = 'download';
    }
    
    // Limit length
    if (sanitized.length > 200) {
      final ext = path.extension(sanitized);
      final name = path.basenameWithoutExtension(sanitized);
      sanitized = '${name.substring(0, 200 - ext.length)}$ext';
    }
    
    return sanitized;
  }

  Future<void> _startDownload(_DownloadTask task) async {
    // This would integrate with the platform-specific download implementation
    // For now, we'll use a simple HTTP client
    _logger.info('UniversalDownloadManager', 'Starting download: ${task.filename}');
    
    try {
      await task.start();
    } catch (e) {
      task.onError?.call(e.toString());
    }
  }
}

/// Internal download task class
class _DownloadTask {
  final String url;
  final String filename;
  final String saveDirectory;
  final void Function(DownloadProgressInfo) onProgress;
  final void Function(DownloadProgressInfo) onComplete;
  final void Function(String) onError;

  http.Client? _client;
  bool _isPaused = false;
  bool _isCancelled = false;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  Stopwatch? _speedTimer;
  int _lastSpeedCheck = 0;

  _DownloadTask({
    required this.url,
    required this.filename,
    required this.saveDirectory,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
  });

  Future<void> start() async {
    _client = http.Client();
    _speedTimer = Stopwatch()..start();

    try {
      // Create request with range header for resume support
      final request = http.Request('GET', Uri.parse(url));
      
      final streamedResponse = await _client!.send(request);
      
      _totalBytes = int.tryParse(
        streamedResponse.headers['content-length'] ?? '0'
      ) ?? 0;

      final file = File(path.join(_saveDirectory, filename));
      final sink = file.openWrite();

      await for (final chunk in streamedResponse.stream) {
        if (_isCancelled) {
          await sink.close();
          await file.delete();
          return;
        }

        while (_isPaused && !_isCancelled) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        sink.add(chunk);
        _downloadedBytes += chunk.length;

        // Update progress every 500ms
        if (_speedTimer!.elapsedMilliseconds - _lastSpeedCheck > 500) {
          _updateProgress();
          _lastSpeedCheck = _speedTimer!.elapsedMilliseconds;
        }
      }

      await sink.close();
      _complete();
    } catch (e) {
      onError(e.toString());
    } finally {
      _client?.close();
      _speedTimer?.stop();
    }
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  void cancel() {
    _isCancelled = true;
    _client?.close();
    _speedTimer?.stop();
  }

  void _updateProgress() {
    final elapsed = _speedTimer!.elapsedMilliseconds / 1000;
    final speed = elapsed > 0 ? _downloadedBytes / elapsed : 0;

    final info = DownloadProgressInfo(
      id: url.hashCode.abs().toString(),
      url: url,
      filename: filename,
      totalBytes: _totalBytes,
      downloadedBytes: _downloadedBytes,
      speed: speed,
      status: UniversalDownloadStatus.downloading,
      savePath: path.join(_saveDirectory, filename),
    );

    onProgress(info);
  }

  void _complete() {
    final info = DownloadProgressInfo(
      id: url.hashCode.abs().toString(),
      url: url,
      filename: filename,
      totalBytes: _totalBytes,
      downloadedBytes: _downloadedBytes,
      speed: 0,
      status: UniversalDownloadStatus.completed,
      savePath: path.join(_saveDirectory, filename),
    );

    onComplete(info);
  }
}

/// Global download manager instance
final downloadManager = UniversalDownloadManager();
