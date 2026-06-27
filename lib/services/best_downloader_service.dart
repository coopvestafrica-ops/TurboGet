import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'database_service.dart';
import 'logger_service.dart';
import 'notification_service.dart';
import 'media_type_service.dart';

/// Download status enum
enum DownloadStatus {
  pending,
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Download item model for persistence
class PersistedDownload {
  final String id;
  final String url;
  final String filename;
  final String? downloadPath;
  final String? tempPath;
  final int totalSize;
  final int downloadedSize;
  final int progress;
  final double speed;
  final DownloadStatus status;
  final String? error;
  final int createdAt;
  final int? completedAt;
  final int? lastResumeAt;
  final int retryCount;
  final List<DownloadSegment> segments;

  PersistedDownload({
    required this.id,
    required this.url,
    required this.filename,
    this.downloadPath,
    this.tempPath,
    this.totalSize = 0,
    this.downloadedSize = 0,
    this.progress = 0,
    this.speed = 0,
    this.status = DownloadStatus.pending,
    this.error,
    required this.createdAt,
    this.completedAt,
    this.lastResumeAt,
    this.retryCount = 0,
    this.segments = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'url': url,
    'filename': filename,
    'download_path': downloadPath,
    'temp_path': tempPath,
    'total_size': totalSize,
    'downloaded_size': downloadedSize,
    'progress': progress,
    'speed': speed,
    'status': status.name,
    'error': error,
    'created_at': createdAt,
    'completed_at': completedAt,
    'last_resume_at': lastResumeAt,
    'retry_count': retryCount,
    'segments': segments.map((s) => s.toMap()).toList(),
  };

  factory PersistedDownload.fromMap(Map<String, dynamic> map) {
    return PersistedDownload(
      id: map['id'],
      url: map['url'],
      filename: map['filename'],
      downloadPath: map['download_path'],
      tempPath: map['temp_path'],
      totalSize: map['total_size'] ?? 0,
      downloadedSize: map['downloaded_size'] ?? 0,
      progress: map['progress'] ?? 0,
      speed: (map['speed'] ?? 0).toDouble(),
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DownloadStatus.pending,
      ),
      error: map['error'],
      createdAt: map['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
      completedAt: map['completed_at'],
      lastResumeAt: map['last_resume_at'],
      retryCount: map['retry_count'] ?? 0,
      segments: (map['segments'] as List<dynamic>?)
          ?.map((s) => DownloadSegment.fromMap(s))
          .toList() ?? [],
    );
  }

  PersistedDownload copyWith({
    int? totalSize,
    int? downloadedSize,
    int? progress,
    double? speed,
    DownloadStatus? status,
    String? error,
    String? downloadPath,
    String? tempPath,
    int? completedAt,
    int? lastResumeAt,
    int? retryCount,
    List<DownloadSegment>? segments,
  }) {
    return PersistedDownload(
      id: id,
      url: url,
      filename: filename,
      downloadPath: downloadPath ?? this.downloadPath,
      tempPath: tempPath ?? this.tempPath,
      totalSize: totalSize ?? this.totalSize,
      downloadedSize: downloadedSize ?? this.downloadedSize,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      status: status ?? this.status,
      error: error,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      lastResumeAt: lastResumeAt ?? this.lastResumeAt,
      retryCount: retryCount ?? this.retryCount,
      segments: segments ?? this.segments,
    );
  }
}

/// Download segment for parallel downloads
class DownloadSegment {
  final int index;
  final int start;
  final int end;
  final int downloadedBytes;
  final bool isComplete;

  DownloadSegment({
    required this.index,
    required this.start,
    required this.end,
    this.downloadedBytes = 0,
    this.isComplete = false,
  });

  Map<String, dynamic> toMap() => {
    'index': index,
    'start': start,
    'end': end,
    'downloaded_bytes': downloadedBytes,
    'is_complete': isComplete,
  };

  factory DownloadSegment.fromMap(Map<String, dynamic> map) {
    return DownloadSegment(
      index: map['index'],
      start: map['start'],
      end: map['end'],
      downloadedBytes: map['downloaded_bytes'] ?? 0,
      isComplete: map['is_complete'] ?? false,
    );
  }

  DownloadSegment copyWith({
    int? downloadedBytes,
    bool? isComplete,
  }) {
    return DownloadSegment(
      index: index,
      start: start,
      end: end,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// Progress callback type
typedef DownloadProgressCallback = void Function(PersistedDownload download);
typedef DownloadCompleteCallback = void Function(PersistedDownload download);
typedef DownloadErrorCallback = void Function(PersistedDownload download, String error);

/// BEST DOWNLOADER SERVICE - Ultra-high speed download manager with resume support
/// Designed by Ayanlowo Olatunji Ayobami
class BestDownloaderService {
  static final BestDownloaderService _instance = BestDownloaderService._internal();
  factory BestDownloaderService() => _instance;
  BestDownloaderService._internal();

  final LoggerService _logger = logger;
  final DatabaseService _database = DatabaseService();
  final NotificationService _notifications = notificationService;
  final MediaTypeService _mediaType = mediaTypeService;

  // Configuration
  static const int MAX_CONCURRENT_DOWNLOADS = 5;
  static const int MAX_SEGMENTS_PER_DOWNLOAD = 16;
  static const int MIN_SEGMENT_SIZE = 512 * 1024; // 512KB minimum
  static const int BUFFER_SIZE = 64 * 1024; // 64KB buffer
  static const int PROGRESS_UPDATE_INTERVAL = 500; // ms
  static const int MAX_RETRIES = 5;
  static const int RETRY_BASE_DELAY = 2000; // 2 seconds base delay

  // State
  final Map<String, _ActiveDownload> _activeDownloads = {};
  final Map<String, PersistedDownload> _downloads = {};
  bool _isInitialized = false;
  String _downloadDirectory = '';
  
  // Callbacks
  DownloadProgressCallback? onProgress;
  DownloadCompleteCallback? onComplete;
  DownloadErrorCallback? onError;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _logger.info('BestDownloader', 'Initializing...');

    // Get download directory
    final directory = await getExternalStorageDirectory();
    _downloadDirectory = directory != null
        ? '${directory.path}/TurboGet'
        : (await getApplicationDocumentsDirectory()).path;

    // Ensure directory exists
    final dir = Directory(_downloadDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Load persisted downloads
    await _loadPersistedDownloads();

    // Initialize notifications
    await _notifications.initialize();

    _isInitialized = true;
    _logger.info('BestDownloader', 'Initialized at $_downloadDirectory');
    _logger.info('BestDownloader', 'Loaded ${_downloads.length} persisted downloads');
  }

  /// Load persisted downloads from database
  Future<void> _loadPersistedDownloads() async {
    try {
      final dbDownloads = await _database.getAllDownloads();
      
      for (final dbDownload in dbDownloads) {
        final statusStr = dbDownload['status']?.toString() ?? 'pending';
        final status = DownloadStatus.values.firstWhere(
          (e) => e.name == statusStr,
          orElse: () => DownloadStatus.pending,
        );

        // Only restore non-completed downloads
        if (status != DownloadStatus.completed && status != DownloadStatus.cancelled) {
          final download = PersistedDownload.fromMap(dbDownload);
          _downloads[download.id] = download;
          
          // If was downloading, set to paused so user can resume
          if (status == DownloadStatus.downloading) {
            _downloads[download.id] = download.copyWith(
              status: DownloadStatus.paused,
            );
          }
        } else {
          final download = PersistedDownload.fromMap(dbDownload);
          _downloads[download.id] = download;
        }
      }
    } catch (e) {
      _logger.error('BestDownloader', 'Failed to load persisted downloads', error: e);
    }
  }

  /// Save download to database
  Future<void> _saveDownload(PersistedDownload download) async {
    try {
      _downloads[download.id] = download;
      
      // Insert or update in database
      await _database.insertDownload(download.toMap());
    } catch (e) {
      _logger.error('BestDownloader', 'Failed to save download', error: e);
    }
  }

  /// Start a new download
  Future<PersistedDownload> startDownload(String url, {String? filename}) async {
    if (!_isInitialized) await initialize();

    // Generate ID and filename
    final id = url.hashCode.abs().toString();
    final resolvedFilename = filename ?? _extractFilename(url);

    // Check if already downloading
    if (_downloads.containsKey(id)) {
      final existing = _downloads[id]!;
      if (existing.status == DownloadStatus.downloading) {
        return existing;
      }
      // Resume if paused or failed
      return resumeDownload(id);
    }

    // Create download entry
    final download = PersistedDownload(
      id: id,
      url: url,
      filename: resolvedFilename,
      status: DownloadStatus.queued,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      downloadPath: path.join(_downloadDirectory, resolvedFilename),
      tempPath: path.join(_downloadDirectory, '.$resolvedFilename.tmp'),
    );

    await _saveDownload(download);

    // Start download process
    _startDownloadInternal(download);

    return download;
  }

  /// Resume a paused or failed download
  Future<PersistedDownload> resumeDownload(String id) async {
    final download = _downloads[id];
    if (download == null) {
      throw Exception('Download not found: $id');
    }

    if (download.status == DownloadStatus.completed) {
      return download;
    }

    _logger.info('BestDownloader', 'Resuming download: ${download.filename}');

    // Update status
    final updated = download.copyWith(
      status: DownloadStatus.downloading,
      lastResumeAt: DateTime.now().millisecondsSinceEpoch,
      error: null,
    );
    await _saveDownload(updated);

    _startDownloadInternal(updated);

    return updated;
  }

  /// Pause a download
  Future<void> pauseDownload(String id) async {
    final active = _activeDownloads[id];
    if (active != null) {
      active.isPaused = true;
      _logger.info('BestDownloader', 'Paused download: $id');
    }

    final download = _downloads[id];
    if (download != null) {
      final updated = download.copyWith(status: DownloadStatus.paused);
      await _saveDownload(updated);
    }
  }

  /// Cancel a download
  Future<void> cancelDownload(String id) async {
    final active = _activeDownloads[id];
    if (active != null) {
      active.isCancelled = true;
      active.cancelToken?.cancel();
      _activeDownloads.remove(id);
    }

    final download = _downloads[id];
    if (download != null) {
      // Delete temp file if exists
      if (download.tempPath != null) {
        final tempFile = File(download.tempPath!);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }

      final updated = download.copyWith(status: DownloadStatus.cancelled);
      await _saveDownload(updated);
    }

    await _notifications.cancelDownloadNotification(id);
    _logger.info('BestDownloader', 'Cancelled download: $id');
  }

  /// Get download by ID
  PersistedDownload? getDownload(String id) => _downloads[id];

  /// Get all downloads
  List<PersistedDownload> getAllDownloads() => _downloads.values.toList();

  /// Get active downloads
  List<PersistedDownload> getActiveDownloads() =>
      _downloads.values.where((d) => d.status == DownloadStatus.downloading).toList();

  /// Get paused downloads
  List<PersistedDownload> getPausedDownloads() =>
      _downloads.values.where((d) => d.status == DownloadStatus.paused).toList();

  /// Get completed downloads
  List<PersistedDownload> getCompletedDownloads() =>
      _downloads.values.where((d) => d.status == DownloadStatus.completed).toList();

  /// Resume all paused downloads on app startup
  Future<void> resumeAllPausedDownloads() async {
    _logger.info('BestDownloader', 'Resuming all paused downloads...');
    
    for (final download in getPausedDownloads()) {
      if (download.status == DownloadStatus.paused) {
        await resumeDownload(download.id);
      }
    }
  }

  /// Start download process internally
  Future<void> _startDownloadInternal(PersistedDownload download) async {
    if (_activeDownloads.containsKey(download.id)) return;

    final active = _ActiveDownload(
      download: download,
      tasks: [],
    );
    _activeDownloads[download.id] = active;

    _downloadProcess(download.id);
  }

  /// Main download processing function
  Future<void> _downloadProcess(String id) async {
    final active = _activeDownloads[id];
    if (active == null) return;

    try {
      var download = active.download;

      // Phase 1: Get file metadata
      if (download.totalSize == 0) {
        download = await _getFileMetadata(download);
      }

      // Phase 2: Create segments for parallel download
      if (download.segments.isEmpty) {
        download = _createSegments(download);
      }

      // Phase 3: Download with segments
      await _downloadWithSegments(id, download);

    } catch (e) {
      _logger.error('BestDownloader', 'Download failed: $id', error: e);
      
      final download = _downloads[id];
      if (download != null) {
        final retryCount = download.retryCount;
        
        if (retryCount < MAX_RETRIES) {
          // Retry with exponential backoff
          final delay = RETRY_BASE_DELAY * math.pow(2, retryCount);
          _logger.info('BestDownloader', 'Retrying in ${delay}ms (attempt ${retryCount + 1})');
          
          await Future.delayed(Duration(milliseconds: delay));
          
          final updated = download.copyWith(
            retryCount: retryCount + 1,
            status: DownloadStatus.queued,
          );
          await _saveDownload(updated);
          
          _startDownloadInternal(updated);
        } else {
          // Max retries reached
          final updated = download.copyWith(
            status: DownloadStatus.failed,
            error: e.toString(),
          );
          await _saveDownload(updated);
          
          onError?.call(updated, e.toString());
          await _notifications.showDownloadFailed(
            downloadId: download.id,
            filename: download.filename,
            error: e.toString(),
          );
        }
      }
    }
  }

  /// Get file metadata (size, supports ranges)
  Future<PersistedDownload> _getFileMetadata(PersistedDownload download) async {
    _logger.info('BestDownloader', 'Getting metadata for: ${download.url}');

    try {
      final response = await http.head(Uri.parse(download.url));
      
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final acceptRanges = response.headers['accept-ranges']?.toLowerCase() == 'bytes';

      _logger.info('BestDownloader', 'File size: $contentLength, Accept ranges: $acceptRanges');

      final updated = download.copyWith(
        totalSize: contentLength,
        downloadPath: path.join(_downloadDirectory, download.filename),
        tempPath: path.join(_downloadDirectory, '.${download.filename}.tmp'),
      );

      await _saveDownload(updated);
      return updated;
    } catch (e) {
      _logger.error('BestDownloader', 'Failed to get metadata', error: e);
      rethrow;
    }
  }

  /// Create download segments for parallel download
  PersistedDownload _createSegments(PersistedDownload download) {
    if (download.totalSize == 0) {
      // No segment support for unknown size
      return download;
    }

    final segmentSize = _calculateOptimalSegmentSize(download.totalSize);
    final segments = <DownloadSegment>[];
    var start = 0;
    var index = 0;

    while (start < download.totalSize) {
      final end = math.min(start + segmentSize - 1, download.totalSize - 1);
      segments.add(DownloadSegment(
        index: index++,
        start: start,
        end: end,
      ));
      start = end + 1;
    }

    _logger.info('BestDownloader', 'Created ${segments.length} segments');

    final updated = download.copyWith(segments: segments);
    _saveDownload(updated);
    return updated;
  }

  int _calculateOptimalSegmentSize(int fileSize) {
    if (fileSize < 5 * 1024 * 1024) return 512 * 1024; // 512KB for < 5MB
    if (fileSize < 50 * 1024 * 1024) return 1024 * 1024; // 1MB for < 50MB
    if (fileSize < 200 * 1024 * 1024) return 2 * 1024 * 1024; // 2MB for < 200MB
    if (fileSize < 1024 * 1024 * 1024) return 4 * 1024 * 1024; // 4MB for < 1GB
    return 8 * 1024 * 1024; // 8MB for >= 1GB
  }

  /// Download with parallel segments
  Future<void> _downloadWithSegments(String id, PersistedDownload download) async {
    final active = _activeDownloads[id];
    if (active == null) return;

    final tempPath = download.tempPath ?? path.join(_downloadDirectory, '.${download.filename}.tmp');
    final tempFile = File(tempPath);
    
    // Create or open temp file
    final raf = await tempFile.open(mode: FileMode.write);
    
    // Pre-allocate file size
    if (download.totalSize > 0) {
      await raf.setPosition(download.totalSize - 1);
      await raf.writeByte(0);
      await raf.setPosition(0);
    }

    final segments = download.segments.isNotEmpty ? download.segments : [
      DownloadSegment(index: 0, start: 0, end: download.totalSize > 0 ? download.totalSize - 1 : 0),
    ];

    // Start segment downloads
    final futures = <Future>[];
    var lastProgressUpdate = DateTime.now();
    var totalDownloaded = download.downloadedSize;

    for (final segment in segments) {
      // Skip completed segments
      if (segment.isComplete) continue;

      futures.add(_downloadSegment(
        id: id,
        url: download.url,
        segment: segment,
        raf: raf,
        onProgress: (bytes) {
          totalDownloaded += bytes;
          
          final now = DateTime.now();
          if (now.difference(lastProgressUpdate).inMilliseconds >= PROGRESS_UPDATE_INTERVAL) {
            final speed = totalDownloaded / (now.difference(DateTime.fromMillisecondsSinceEpoch(download.createdAt)).inSeconds + 1);
            final progress = download.totalSize > 0 ? (totalDownloaded * 100 / download.totalSize).round() : 0;
            
            final updated = download.copyWith(
              downloadedSize: totalDownloaded,
              progress: progress,
              speed: speed,
            );
            _saveDownload(updated);
            
            onProgress?.call(updated);
            _notifications.showDownloadProgress(
              downloadId: id,
              filename: download.filename,
              progress: progress,
              downloadedBytes: totalDownloaded,
              totalBytes: download.totalSize,
            );
            
            lastProgressUpdate = now;
          }
        },
      ));
    }

    // Wait for all segments
    await Future.wait(futures);

    // Close file
    await raf.close();

    // Move to final location
    final finalPath = download.downloadPath ?? path.join(_downloadDirectory, download.filename);
    await tempFile.rename(finalPath);

    // Update status to completed
    final updated = download.copyWith(
      status: DownloadStatus.completed,
      downloadedSize: download.totalSize,
      progress: 100,
      speed: 0,
      completedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _saveDownload(updated);

    _activeDownloads.remove(id);

    onComplete?.call(updated);
    await _notifications.showDownloadComplete(
      downloadId: id,
      filename: download.filename,
      filePath: finalPath,
      fileSize: download.totalSize,
    );

    _logger.info('BestDownloader', 'Download completed: ${download.filename}');
  }

  /// Download a single segment
  Future<void> _downloadSegment({
    required String id,
    required String url,
    required DownloadSegment segment,
    required RandomAccessFile raf,
    required Function(int) onProgress,
  }) async {
    final active = _activeDownloads[id];
    if (active == null) return;

    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Range'] = 'bytes=${segment.start}-${segment.end}';

      final response = await http.Client().send(request);
      
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Server returned ${response.statusCode}');
      }

      var segmentDownloaded = 0;
      final buffer = List<int>.filled(BUFFER_SIZE, 0);

      await for (final chunk in response.stream) {
        // Check for pause/cancel
        while (active.isPaused && !active.isCancelled) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (active.isCancelled) {
          throw Exception('Download cancelled');
        }

        // Write to file at correct position
        await raf.setPosition(segment.start + segmentDownloaded);
        await raf.writeFrom(chunk);
        
        segmentDownloaded += chunk.length;
        onProgress(chunk.length);
      }
    } catch (e) {
      if (!active.isCancelled) {
        _logger.error('BestDownloader', 'Segment ${segment.index} failed', error: e);
        rethrow;
      }
    }
  }

  String _extractFilename(String url) {
    try {
      final uri = Uri.parse(url);
      var filename = path.basename(uri.path);
      
      if (filename.isEmpty || !filename.contains('.')) {
        final ext = _mediaType.getExtensionFromUrl(url);
        filename = 'download_${DateTime.now().millisecondsSinceEpoch}$ext';
      }

      // Remove query parameters
      if (filename.contains('?')) {
        filename = filename.split('?').first;
      }

      // Sanitize filename
      filename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      return filename;
    } catch (e) {
      return 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Delete completed download
  Future<void> deleteDownload(String id) async {
    final download = _downloads[id];
    if (download == null) return;

    // Delete file
    if (download.downloadPath != null) {
      final file = File(download.downloadPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Remove from storage
    _downloads.remove(id);
    await _database.deleteDownload(id);
    
    _logger.info('BestDownloader', 'Deleted download: ${download.filename}');
  }

  /// Clear all completed downloads
  Future<void> clearCompletedDownloads() async {
    final completed = getCompletedDownloads();
    for (final download in completed) {
      await deleteDownload(download.id);
    }
    _logger.info('BestDownloader', 'Cleared ${completed.length} completed downloads');
  }
}

/// Active download tracking
class _ActiveDownload {
  PersistedDownload download;
  List<Future> tasks;
  bool isPaused = false;
  bool isCancelled = false;
  CancelToken? cancelToken;

  _ActiveDownload({
    required this.download,
    required this.tasks,
    this.isPaused = false,
    this.isCancelled = false,
    this.cancelToken,
  });
}

/// Cancel token for stopping downloads
class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}

/// Extension for MediaTypeService
extension MediaTypeServiceExtension on MediaTypeService {
  String getExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final lastDot = path.lastIndexOf('.');
      if (lastDot != -1 && lastDot < path.length - 1) {
        return path.substring(lastDot);
      }
    } catch (e) {}
    return '';
  }
}

/// Global best downloader instance
final bestDownloader = BestDownloaderService();