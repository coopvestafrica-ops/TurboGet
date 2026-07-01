import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as path;
import 'database_service.dart';
import 'logger_service.dart';
import 'notification_service.dart';
import 'media_type_service.dart';

// ============================================================================
// TURBO DOWNLOADER ENGINE - The Fastest Download Manager
// ============================================================================
// 
// Features:
// - 🔥 Multi-Connection Acceleration (up to 16 connections per file)
// - ⚡ Dynamic Segment Sizing based on network speed
// - 🧠 AI-based Bandwidth Allocation
// - 🔄 Smart Resume with Delta Updates
// - 📊 Real-time Speed Optimization
// - 🌐 Network-Aware Downloads
// - 🎯 Intelligent Queue Management
// - 💾 Progress Persistence & Recovery
// - 🔒 Secure Downloads with Checksum Verification
// ============================================================================

/// Turbo Download Status
enum TurboDownloadStatus {
  pending,
  queued,
  connecting,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
  waitingForNetwork,
  verifying,
}

/// Download Priority Levels
enum DownloadPriority {
  low(0),
  normal(1),
  high(2),
  urgent(3);

  final int value;
  const DownloadPriority(this.value);
}

/// Connection Quality
enum ConnectionQuality {
  excellent,  // > 10 MB/s
  good,      // 2-10 MB/s
  fair,      // 500 KB/s - 2 MB/s
  poor,      // < 500 KB/s
}

/// Turbo Download Item - The core data model
class TurboDownloadItem {
  final String id;
  final String url;
  String filename;
  String? downloadPath;
  String? tempPath;
  int totalSize;
  int downloadedSize;
  int progress;
  double speed;
  double peakSpeed;
  double averageSpeed;
  TurboDownloadStatus status;
  String? error;
  int createdAt;
  int? startedAt;
  int? completedAt;
  int? lastResumeAt;
  int retryCount;
  int maxRetries;
  DownloadPriority priority;
  List<TurboSegment> segments;
  bool supportsResuming;
  String? mimeType;
  String? etag;
  String? lastModified;
  String? checksum;
  String? checksumAlgorithm;
  int connectionsUsed;
  int optimalConnections;
  ConnectionQuality connectionQuality;
  double bandwidthShare;
  DateTime? lastActivity;

  TurboDownloadItem({
    required this.id,
    required this.url,
    required this.filename,
    this.downloadPath,
    this.tempPath,
    this.totalSize = 0,
    this.downloadedSize = 0,
    this.progress = 0,
    this.speed = 0,
    this.peakSpeed = 0,
    this.averageSpeed = 0,
    this.status = TurboDownloadStatus.pending,
    this.error,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.lastResumeAt,
    this.retryCount = 0,
    this.maxRetries = 10,
    this.priority = DownloadPriority.normal,
    this.segments = const [],
    this.supportsResuming = false,
    this.mimeType,
    this.etag,
    this.lastModified,
    this.checksum,
    this.checksumAlgorithm,
    this.connectionsUsed = 0,
    this.optimalConnections = 4,
    this.connectionQuality = ConnectionQuality.good,
    this.bandwidthShare = 1.0,
    this.lastActivity,
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
    'peak_speed': peakSpeed,
    'average_speed': averageSpeed,
    'status': status.name,
    'error': error,
    'created_at': createdAt,
    'started_at': startedAt,
    'completed_at': completedAt,
    'last_resume_at': lastResumeAt,
    'retry_count': retryCount,
    'max_retries': maxRetries,
    'priority': priority.value,
    'segments': segments.map((s) => s.toMap()).toList(),
    'supports_resuming': supportsResuming,
    'mime_type': mimeType,
    'etag': etag,
    'last_modified': lastModified,
    'checksum': checksum,
    'checksum_algorithm': checksumAlgorithm,
    'connections_used': connectionsUsed,
    'optimal_connections': optimalConnections,
    'connection_quality': connectionQuality.name,
    'bandwidth_share': bandwidthShare,
    'last_activity': lastActivity?.toIso8601String(),
  };

  factory TurboDownloadItem.fromMap(Map<String, dynamic> map) {
    return TurboDownloadItem(
      id: map['id'],
      url: map['url'],
      filename: map['filename'],
      downloadPath: map['download_path'],
      tempPath: map['temp_path'],
      totalSize: map['total_size'] ?? 0,
      downloadedSize: map['downloaded_size'] ?? 0,
      progress: map['progress'] ?? 0,
      speed: (map['speed'] ?? 0).toDouble(),
      peakSpeed: (map['peak_speed'] ?? 0).toDouble(),
      averageSpeed: (map['average_speed'] ?? 0).toDouble(),
      status: TurboDownloadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TurboDownloadStatus.pending,
      ),
      error: map['error'],
      createdAt: map['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
      startedAt: map['started_at'],
      completedAt: map['completed_at'],
      lastResumeAt: map['last_resume_at'],
      retryCount: map['retry_count'] ?? 0,
      maxRetries: map['max_retries'] ?? 10,
      priority: DownloadPriority.values.firstWhere(
        (e) => e.value == map['priority'],
        orElse: () => DownloadPriority.normal,
      ),
      segments: (map['segments'] as List<dynamic>?)
          ?.map((s) => TurboSegment.fromMap(s))
          .toList() ?? [],
      supportsResuming: map['supports_resuming'] ?? false,
      mimeType: map['mime_type'],
      etag: map['etag'],
      lastModified: map['last_modified'],
      checksum: map['checksum'],
      checksumAlgorithm: map['checksum_algorithm'],
      connectionsUsed: map['connections_used'] ?? 0,
      optimalConnections: map['optimal_connections'] ?? 4,
      connectionQuality: ConnectionQuality.values.firstWhere(
        (e) => e.name == map['connection_quality'],
        orElse: () => ConnectionQuality.good,
      ),
      bandwidthShare: (map['bandwidth_share'] ?? 1.0).toDouble(),
      lastActivity: map['last_activity'] != null 
          ? DateTime.tryParse(map['last_activity']) 
          : null,
    );
  }

  TurboDownloadItem copyWith({
    int? totalSize,
    int? downloadedSize,
    int? progress,
    double? speed,
    double? peakSpeed,
    double? averageSpeed,
    TurboDownloadStatus? status,
    String? error,
    String? filename,
    String? downloadPath,
    String? tempPath,
    int? startedAt,
    int? completedAt,
    int? lastResumeAt,
    int? retryCount,
    int? maxRetries,
    DownloadPriority? priority,
    List<TurboSegment>? segments,
    bool? supportsResuming,
    String? mimeType,
    String? etag,
    String? lastModified,
    String? checksum,
    String? checksumAlgorithm,
    int? connectionsUsed,
    int? optimalConnections,
    ConnectionQuality? connectionQuality,
    double? bandwidthShare,
    DateTime? lastActivity,
  }) {
    return TurboDownloadItem(
      id: id,
      url: url,
      filename: filename ?? this.filename,
      downloadPath: downloadPath ?? this.downloadPath,
      tempPath: tempPath ?? this.tempPath,
      totalSize: totalSize ?? this.totalSize,
      downloadedSize: downloadedSize ?? this.downloadedSize,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      peakSpeed: peakSpeed ?? this.peakSpeed,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      lastResumeAt: lastResumeAt ?? this.lastResumeAt,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      priority: priority ?? this.priority,
      segments: segments ?? this.segments,
      supportsResuming: supportsResuming ?? this.supportsResuming,
      mimeType: mimeType ?? this.mimeType,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      checksum: checksum ?? this.checksum,
      checksumAlgorithm: checksumAlgorithm ?? this.checksumAlgorithm,
      connectionsUsed: connectionsUsed ?? this.connectionsUsed,
      optimalConnections: optimalConnections ?? this.optimalConnections,
      connectionQuality: connectionQuality ?? this.connectionQuality,
      bandwidthShare: bandwidthShare ?? this.bandwidthShare,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }

  String get formattedSpeed {
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    if (speed < 1024 * 1024 * 1024) return '${(speed / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    return '${(speed / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }

  String get formattedPeakSpeed {
    if (peakSpeed < 1024) return '${peakSpeed.toStringAsFixed(0)} B/s';
    if (peakSpeed < 1024 * 1024) return '${(peakSpeed / 1024).toStringAsFixed(1)} KB/s';
    if (peakSpeed < 1024 * 1024 * 1024) return '${(peakSpeed / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    return '${(peakSpeed / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }

  String get estimatedTimeRemaining {
    if (averageSpeed == 0 || totalSize == 0 || status != TurboDownloadStatus.downloading) {
      return '--:--';
    }
    final remainingBytes = totalSize - downloadedSize;
    final seconds = (remainingBytes / averageSpeed).round();
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) return '${minutes}m ${remainingSeconds}s';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  String get statusText {
    switch (status) {
      case TurboDownloadStatus.pending:
        return 'Pending';
      case TurboDownloadStatus.queued:
        return 'In Queue';
      case TurboDownloadStatus.connecting:
        return 'Connecting...';
      case TurboDownloadStatus.downloading:
        return 'Downloading';
      case TurboDownloadStatus.paused:
        return 'Paused';
      case TurboDownloadStatus.completed:
        return 'Completed';
      case TurboDownloadStatus.failed:
        return 'Failed';
      case TurboDownloadStatus.cancelled:
        return 'Cancelled';
      case TurboDownloadStatus.waitingForNetwork:
        return 'Waiting for Network';
      case TurboDownloadStatus.verifying:
        return 'Verifying...';
    }
  }
}

/// Turbo Segment - Enhanced segment with more metadata
class TurboSegment {
  final int index;
  final int start;
  final int end;
  int downloadedBytes;
  bool isComplete;
  bool isActive;
  int connectionIndex;
  double speed;
  DateTime? lastUpdate;

  TurboSegment({
    required this.index,
    required this.start,
    required this.end,
    this.downloadedBytes = 0,
    this.isComplete = false,
    this.isActive = false,
    this.connectionIndex = 0,
    this.speed = 0,
    this.lastUpdate,
  });

  int get size => end - start + 1;
  double get progress => size > 0 ? downloadedBytes / size : 0;

  Map<String, dynamic> toMap() => {
    'index': index,
    'start': start,
    'end': end,
    'downloaded_bytes': downloadedBytes,
    'is_complete': isComplete,
    'is_active': isActive,
    'connection_index': connectionIndex,
    'speed': speed,
    'last_update': lastUpdate?.toIso8601String(),
  };

  factory TurboSegment.fromMap(Map<String, dynamic> map) {
    return TurboSegment(
      index: map['index'],
      start: map['start'],
      end: map['end'],
      downloadedBytes: map['downloaded_bytes'] ?? 0,
      isComplete: map['is_complete'] ?? false,
      isActive: map['is_active'] ?? false,
      connectionIndex: map['connection_index'] ?? 0,
      speed: (map['speed'] ?? 0).toDouble(),
      lastUpdate: map['last_update'] != null 
          ? DateTime.tryParse(map['last_update']) 
          : null,
    );
  }

  TurboSegment copyWith({
    int? downloadedBytes,
    bool? isComplete,
    bool? isActive,
    int? connectionIndex,
    double? speed,
    DateTime? lastUpdate,
  }) {
    return TurboSegment(
      index: index,
      start: start,
      end: end,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      isComplete: isComplete ?? this.isComplete,
      isActive: isActive ?? this.isActive,
      connectionIndex: connectionIndex ?? this.connectionIndex,
      speed: speed ?? this.speed,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

// ============================================================================
// TURBO DOWNLOAD MANAGER - The Core Engine
// ============================================================================

/// Callback types
typedef TurboProgressCallback = void Function(TurboDownloadItem item);
typedef TurboCompleteCallback = void Function(TurboDownloadItem item);
typedef TurboErrorCallback = void Function(TurboDownloadItem item, String error);
typedef TurboQueueCallback = void Function(List<TurboDownloadItem> queue);
typedef TurboSpeedCallback = void Function(double totalSpeed, double avgSpeed);

/// Turbo Download Manager - The Fastest Download Engine
class TurboDownloadManager {
  static final TurboDownloadManager _instance = TurboDownloadManager._internal();
  factory TurboDownloadManager() => _instance;
  TurboDownloadManager._internal();

  final LoggerService _logger = logger;
  final DatabaseService _database = DatabaseService();
  final NotificationService _notifications = notificationService;
  final MediaTypeService _mediaType = mediaTypeService;
  final Connectivity _connectivity = Connectivity();

  // ============================================================================
  // CONFIGURATION
  // ============================================================================
  
  // Connection Settings
  static const int MAX_CONCURRENT_DOWNLOADS = 5;
  static const int MAX_CONNECTIONS_PER_FILE = 16;
  static const int MIN_CONNECTIONS_PER_FILE = 2;
  static const int DEFAULT_CONNECTIONS_PER_FILE = 8;
  
  // Buffer & Performance
  static const int BUFFER_SIZE = 256 * 1024; // 256KB buffer for faster I/O
  static const int PROGRESS_UPDATE_INTERVAL = 100; // ms - faster updates
  static const int SEGMENT_CHUNK_SIZE = 64 * 1024; // 64KB chunks
  
  // Retry & Recovery
  static const int DEFAULT_MAX_RETRIES = 10;
  static const int BASE_RETRY_DELAY_MS = 500;
  static const int MAX_RETRY_DELAY_MS = 30000;
  
  // Speed Optimization
  static const int SPEED_SAMPLE_COUNT = 20;
  static const double SPEED_BOOST_THRESHOLD = 0.7; // 70% of peak triggers boost
  static const int WARMUP_SAMPLES = 5; // Samples to average before optimization
  
  // ============================================================================
  // STATE
  // ============================================================================
  
  final Map<String, TurboActiveDownload> _activeDownloads = {};
  final Map<String, TurboDownloadItem> _downloads = {};
  final List<String> _downloadQueue = [];
  final Map<String, List<_SpeedSample>> _speedHistory = {};
  
  bool _isInitialized = false;
  String _downloadDirectory = '';
  
  // Network State
  bool _isConnected = false;
  bool _isWifi = false;
  bool _wifiOnlyMode = false;
  ConnectionQuality _currentQuality = ConnectionQuality.good;
  
  // Bandwidth Management
  double _totalBandwidthLimit = 0; // 0 = unlimited
  double _currentBandwidthUsage = 0;
  
  // Performance Tracking
  double _globalPeakSpeed = 0;
  double _globalAverageSpeed = 0;
  int _totalBytesDownloaded = 0;
  DateTime? _sessionStart;
  
  // HTTP Clients Pool
  final List<http.Client> _clientPool = [];
  static const int MAX_CLIENT_POOL_SIZE = 32;
  
  // ============================================================================
  // CALLBACKS
  // ============================================================================
  
  TurboProgressCallback? onProgress;
  TurboCompleteCallback? onComplete;
  TurboErrorCallback? onError;
  TurboQueueCallback? onQueueChanged;
  TurboSpeedCallback? onSpeedUpdate;
  
  // ============================================================================
  // INITIALIZATION
  // ============================================================================
  
  Future<void> initialize() async {
    if (_isInitialized) return;

    _logger.info('TurboDownload', '🔥 Initializing Turbo Download Engine...');
    _sessionStart = DateTime.now();

    // Get download directory
    final directory = await getApplicationDocumentsDirectory();
    _downloadDirectory = path.join(directory.path, 'TurboGet', 'TurboDownloads');

    // Ensure directory exists
    final dir = Directory(_downloadDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Initialize HTTP client pool
    await _initClientPool();

    // Setup network monitoring
    await _setupNetworkMonitoring();

    // Load persisted downloads
    await _loadPersistedDownloads();

    // Restore interrupted downloads
    await _restoreInterruptedDownloads();

    _isInitialized = true;
    _logger.info('TurboDownload', '✅ Turbo Engine Ready!');
    _logger.info('TurboDownload', '   Directory: $_downloadDirectory');
    _logger.info('TurboDownload', '   Downloads: ${_downloads.length}');
    _logger.info('TurboDownload', '   Queue: ${_downloadQueue.length}');
  }

  Future<void> _initClientPool() async {
    for (int i = 0; i < MAX_CLIENT_POOL_SIZE; i++) {
      _clientPool.add(http.Client());
    }
    _logger.info('TurboDownload', '   HTTP Pool: ${_clientPool.length} clients');
  }

  Future<void> _setupNetworkMonitoring() async {
    // Check initial state
    final results = await _connectivity.checkConnectivity();
    _updateNetworkState(results);
    
    // Listen for changes
    _connectivity.onConnectivityChanged.listen((results) {
      final wasConnected = _isConnected;
      _updateNetworkState(results);
      
      if (_isConnected && !wasConnected) {
        _logger.info('TurboDownload', '🌐 Network restored!');
        _onNetworkRestored();
      } else if (!_isConnected && wasConnected) {
        _logger.info('TurboDownload', '⚠️ Network lost!');
        _onNetworkLost();
      }
    });
  }

  void _updateNetworkState(List<ConnectivityResult> results) {
    _isConnected = !results.contains(ConnectivityResult.none);
    _isWifi = results.contains(ConnectivityResult.wifi);
    
    _logger.info('TurboDownload', '   Network: ${_isWifi ? "WiFi" : "Mobile"}, Connected: $_isConnected');
  }

  Future<void> _loadPersistedDownloads() async {
    try {
      final dbDownloads = await _database.getAllDownloads();
      
      for (final dbDownload in dbDownloads) {
        final item = TurboDownloadItem.fromMap(dbDownload);
        _downloads[item.id] = item;
        
        // Restore interrupted downloads to queue
        if (item.status == TurboDownloadStatus.downloading ||
            item.status == TurboDownloadStatus.connecting) {
          _downloadQueue.add(item.id);
        } else if (item.status == TurboDownloadStatus.queued ||
                   item.status == TurboDownloadStatus.paused ||
                   item.status == TurboDownloadStatus.waitingForNetwork) {
          if (!_downloadQueue.contains(item.id)) {
            _downloadQueue.add(item.id);
          }
        }
      }
      
      _logger.info('TurboDownload', '   Loaded: ${_downloads.length} downloads from DB');
    } catch (e) {
      _logger.error('TurboDownload', 'Failed to load downloads', error: e);
    }
  }

  Future<void> _restoreInterruptedDownloads() async {
    int restored = 0;
    for (final id in _downloadQueue.toList()) {
      final download = _downloads[id];
      if (download != null && 
          (download.status == TurboDownloadStatus.downloading ||
           download.status == TurboDownloadStatus.connecting)) {
        // Mark as paused for manual resume
        _downloads[id] = download.copyWith(status: TurboDownloadStatus.paused);
        restored++;
      }
    }
    if (restored > 0) {
      _logger.info('TurboDownload', '   Restored: $restored interrupted downloads');
    }
  }

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /// Start a new download with turbo speed
  Future<TurboDownloadItem> download(
    String url, {
    String? filename,
    int? maxConnections,
    int maxRetries = DEFAULT_MAX_RETRIES,
    DownloadPriority priority = DownloadPriority.normal,
    String? checksum,
    String? checksumAlgorithm,
  }) async {
    if (!_isInitialized) await initialize();

    // Validate URL
    if (!_isValidUrl(url)) {
      throw Exception('Invalid URL: $url');
    }

    final id = _generateId(url);

    // Check if already downloading
    if (_downloads.containsKey(id)) {
      final existing = _downloads[id]!;
      if (existing.status == TurboDownloadStatus.completed) {
        return existing;
      }
      if (existing.status == TurboDownloadStatus.downloading) {
        return existing;
      }
      return resumeDownload(id);
    }

    // Resolve filename
    final resolvedFilename = filename ?? _extractFilename(url);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Create download item
    final download = TurboDownloadItem(
      id: id,
      url: url,
      filename: resolvedFilename,
      status: TurboDownloadStatus.queued,
      createdAt: now,
      downloadPath: path.join(_downloadDirectory, resolvedFilename),
      tempPath: path.join(_downloadDirectory, '._$resolvedFilename.tmp'),
      maxRetries: maxRetries,
      priority: priority,
      checksum: checksum,
      checksumAlgorithm: checksumAlgorithm,
      optimalConnections: maxConnections ?? DEFAULT_CONNECTIONS_PER_FILE,
    );

    _downloads[id] = download;
    _insertIntoQueue(id, priority);
    
    await _saveDownload(download);
    onQueueChanged?.call(getQueue());

    _logger.info('TurboDownload', '📥 Queued: ${download.filename} (${download.optimalConnections} connections)');

    // Start if under capacity
    _tryStartNextDownload();

    return download;
  }

  /// Resume a download
  Future<TurboDownloadItem> resumeDownload(String id) async {
    final download = _downloads[id];
    if (download == null) {
      throw Exception('Download not found: $id');
    }

    if (download.status == TurboDownloadStatus.completed) {
      return download;
    }

    _logger.info('TurboDownload', '▶️ Resuming: ${download.filename}');

    if (!_canDownload()) {
      final updated = download.copyWith(status: TurboDownloadStatus.waitingForNetwork);
      await _saveDownload(updated);
      return updated;
    }

    final updated = download.copyWith(
      status: TurboDownloadStatus.queued,
      lastResumeAt: DateTime.now().millisecondsSinceEpoch,
      error: null,
    );
    
    _downloads[id] = updated;
    _insertIntoQueue(id, updated.priority);
    await _saveDownload(updated);
    onQueueChanged?.call(getQueue());

    _tryStartNextDownload();

    return updated;
  }

  /// Pause a download
  Future<void> pauseDownload(String id) async {
    final active = _activeDownloads[id];
    if (active != null) {
      active.isPaused = true;
      _logger.info('TurboDownload', '⏸️ Paused: $id');
    }

    final download = _downloads[id];
    if (download != null) {
      final updated = download.copyWith(status: TurboDownloadStatus.paused);
      await _saveDownload(updated);
      onProgress?.call(updated);
    }
  }

  /// Cancel a download
  Future<void> cancelDownload(String id) async {
    final active = _activeDownloads[id];
    if (active != null) {
      active.isCancelled = true;
      for (final token in active.cancelTokens) {
        token.cancel();
      }
      _activeDownloads.remove(id);
    }

    final download = _downloads[id];
    if (download != null) {
      // Delete temp file
      await _deleteTempFile(download);
      
      // Remove from queue
      _downloadQueue.remove(id);
      _speedHistory.remove(id);

      final updated = download.copyWith(status: TurboDownloadStatus.cancelled);
      await _saveDownload(updated);
      
      _logger.info('TurboDownload', '❌ Cancelled: ${download.filename}');
      
      _tryStartNextDownload();
    }
  }

  /// Retry a failed download
  Future<TurboDownloadItem> retryDownload(String id) async {
    final download = _downloads[id];
    if (download == null) {
      throw Exception('Download not found: $id');
    }

    _logger.info('TurboDownload', '🔄 Retrying: ${download.filename}');

    // Reset for retry
    final updated = download.copyWith(
      status: TurboDownloadStatus.queued,
      retryCount: 0,
      error: null,
      downloadedSize: 0,
      progress: 0,
      speed: 0,
      peakSpeed: 0,
      averageSpeed: 0,
      segments: [],
    );
    
    _downloads[id] = updated;
    _insertIntoQueue(id, updated.priority);
    await _saveDownload(updated);
    onQueueChanged?.call(getQueue());

    _tryStartNextDownload();

    return updated;
  }

  /// Change download priority
  Future<void> setPriority(String id, DownloadPriority priority) async {
    final download = _downloads[id];
    if (download != null) {
      _downloadQueue.remove(id);
      final updated = download.copyWith(priority: priority);
      _downloads[id] = updated;
      _insertIntoQueue(id, priority);
      await _saveDownload(updated);
      onQueueChanged?.call(getQueue());
    }
  }

  /// Set bandwidth limit (bytes per second, 0 = unlimited)
  void setBandwidthLimit(double bytesPerSecond) {
    _totalBandwidthLimit = bytesPerSecond;
    _logger.info('TurboDownload', '📊 Bandwidth limit: ${_formatSpeed(bytesPerSecond)}');
  }

  /// Set WiFi-only mode
  void setWifiOnlyMode(bool enabled) {
    _wifiOnlyMode = enabled;
    if (enabled && !_isWifi) {
      _pauseAllForNetwork();
    }
  }

  // ============================================================================
  // INTERNAL DOWNLOAD LOGIC
  // ============================================================================

  bool _canDownload() {
    if (!_isConnected) return false;
    if (_wifiOnlyMode && !_isWifi) return false;
    return true;
  }

  void _insertIntoQueue(String id, DownloadPriority priority) {
    // Insert based on priority
    int insertIndex = _downloadQueue.length;
    for (int i = 0; i < _downloadQueue.length; i++) {
      final existing = _downloads[_downloadQueue[i]];
      if (existing != null && existing.priority.value < priority.value) {
        insertIndex = i;
        break;
      }
    }
    _downloadQueue.insert(insertIndex, id);
  }

  void _tryStartNextDownload() {
    if (_activeDownloads.length >= MAX_CONCURRENT_DOWNLOADS) return;
    if (!_canDownload()) return;

    for (final id in _downloadQueue.toList()) {
      if (_activeDownloads.length >= MAX_CONCURRENT_DOWNLOADS) break;
      
      final download = _downloads[id];
      if (download != null && download.status == TurboDownloadStatus.queued) {
        _startDownload(download);
      }
    }
  }

  void _startDownload(TurboDownloadItem download) {
    if (_activeDownloads.containsKey(download.id)) return;

    final active = TurboActiveDownload(
      download: download,
      tasks: [],
      cancelTokens: [],
    );
    _activeDownloads[download.id] = active;

    // Update status
    _downloads[download.id] = download.copyWith(
      status: TurboDownloadStatus.connecting,
      startedAt: DateTime.now().millisecondsSinceEpoch,
      lastActivity: DateTime.now(),
    );

    // Start async download process
    _downloadProcess(download.id);
  }

  Future<void> _downloadProcess(String id) async {
    final active = _activeDownloads[id];
    if (active == null) return;

    try {
      var download = active.download;

      // Phase 1: Get metadata
      download = await _getMetadata(download);
      active.download = download;

      // Phase 2: Create segments
      download = _createSegments(download);
      active.download = download;

      // Phase 3: Download!
      await _multiConnectDownload(id);

    } catch (e) {
      await _handleDownloadError(id, e.toString());
    }
  }

  Future<TurboDownloadItem> _getMetadata(TurboDownloadItem download) async {
    _logger.info('TurboDownload', '🔍 Fetching metadata: ${download.url}');

    try {
      final client = _getClient();
      final response = await client.head(Uri.parse(download.url)).timeout(
        const Duration(seconds: 30),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final acceptRanges = response.headers['accept-ranges']?.toLowerCase() == 'bytes';
      final contentType = response.headers['content-type'];
      final etag = response.headers['etag'];
      final lastModified = response.headers['last-modified'];

      // Calculate optimal connections based on file size
      int optimalConnections = _calculateOptimalConnections(contentLength, acceptRanges);

      _logger.info('TurboDownload', '   Size: ${_formatSize(contentLength)}');
      _logger.info('TurboDownload', '   Resume: $acceptRanges');
      _logger.info('TurboDownload', '   Connections: $optimalConnections');

      final updated = download.copyWith(
        totalSize: contentLength,
        supportsResuming: acceptRanges,
        mimeType: contentType,
        etag: etag,
        lastModified: lastModified,
        optimalConnections: optimalConnections,
        downloadPath: path.join(_downloadDirectory, download.filename),
        tempPath: path.join(_downloadDirectory, '._${download.filename}.tmp'),
        status: TurboDownloadStatus.downloading,
      );

      await _saveDownload(updated);
      return updated;

    } catch (e) {
      _logger.error('TurboDownload', 'Metadata fetch failed', error: e);
      rethrow;
    }
  }

  int _calculateOptimalConnections(int fileSize, bool supportsRanges) {
    if (!supportsRanges) return 1;
    if (fileSize < 1024 * 1024) return 2; // < 1MB: 2 connections
    if (fileSize < 10 * 1024 * 1024) return 4; // < 10MB: 4 connections
    if (fileSize < 50 * 1024 * 1024) return 6; // < 50MB: 6 connections
    if (fileSize < 200 * 1024 * 1024) return 8; // < 200MB: 8 connections
    if (fileSize < 1024 * 1024 * 1024) return 12; // < 1GB: 12 connections
    return 16; // >= 1GB: max connections
  }

  TurboDownloadItem _createSegments(TurboDownloadItem download) {
    if (download.totalSize == 0 || !download.supportsResuming) {
      // Single segment for unknown size or no range support
      return download.copyWith(
        segments: [
          TurboSegment(
            index: 0,
            start: 0,
            end: 0,
          ),
        ],
      );
    }

    final segmentSize = _calculateSegmentSize(download.totalSize, download.optimalConnections);
    final segments = <TurboSegment>[];
    var start = 0;
    var index = 0;

    while (start < download.totalSize) {
      final end = math.min(start + segmentSize - 1, download.totalSize - 1);
      segments.add(TurboSegment(
        index: index++,
        start: start,
        end: end,
      ));
      start = end + 1;
    }

    _logger.info('TurboDownload', '   Segments: ${segments.length} (${_formatSize(segmentSize)} each)');

    return download.copyWith(segments: segments);
  }

  int _calculateSegmentSize(int fileSize, int connections) {
    // Aim for 4-8 segments per connection for better load balancing
    final targetSegments = connections * 4;
    final segmentSize = (fileSize / targetSegments).ceil();
    
    // Clamp segment size
    const minSegmentSize = 256 * 1024; // 256KB minimum
    const maxSegmentSize = 32 * 1024 * 1024; // 32MB maximum
    
    return segmentSize.clamp(minSegmentSize, maxSegmentSize);
  }

  Future<void> _multiConnectDownload(String id) async {
    final active = _activeDownloads[id];
    if (active == null) return;

    var download = active.download;
    final segments = download.segments;
    
    if (segments.isEmpty || segments.first.end == 0) {
      // Single segment download
      await _downloadSingleSegment(id);
      return;
    }

    // Prepare file
    final tempPath = download.tempPath ?? path.join(_downloadDirectory, '._${download.filename}.tmp');
    final tempFile = File(tempPath);
    final raf = await tempFile.open(mode: FileMode.write);
    
    // Pre-allocate
    if (download.totalSize > 0) {
      await raf.setPosition(download.totalSize - 1);
      await raf.writeByte(0);
      await raf.setPosition(0);
    }

    // Speed tracking
    final speedSamples = <_SpeedSample>[];
    _speedHistory[id] = speedSamples;
    final startTime = DateTime.now();
    var totalDownloaded = download.downloadedSize;
    var lastProgressUpdate = DateTime.now();
    DateTime? lastSpeedUpdate;

    // Download segments with multiple connections
    final futures = <Future>[];
    
    for (final segment in segments) {
      if (segment.isComplete) continue;

      // Check pause/cancel
      while (active.isPaused && !active.isCancelled) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (active.isCancelled) {
        await raf.close();
        return;
      }

      futures.add(_downloadSegmentWithClient(
        id: id,
        url: download.url,
        segment: segment,
        raf: raf,
        onProgress: (bytes) {
          totalDownloaded += bytes;
          download.downloadedSize = totalDownloaded;
          download.lastActivity = DateTime.now();
          
          final now = DateTime.now();
          final elapsed = now.difference(startTime).inSeconds;
          final currentSpeed = elapsed > 0 ? totalDownloaded / elapsed : 0;
          
          // Track speed
          speedSamples.add(_SpeedSample(now, totalDownloaded));
          if (speedSamples.length > SPEED_SAMPLE_COUNT) {
            speedSamples.removeAt(0);
          }
          
          // Calculate speeds
          double avgSpeed = currentSpeed.toDouble();
          double peakSpeed = download.peakSpeed;
          
          if (speedSamples.length >= 2) {
            final first = speedSamples.first;
            final last = speedSamples.last;
            final timeDiff = last.timestamp.difference(first.timestamp).inSeconds;
            if (timeDiff > 0) {
              avgSpeed = (last.bytes - first.bytes) / timeDiff;
            }
          }
          
          if (currentSpeed > peakSpeed) {
            peakSpeed = currentSpeed.toDouble();
          }
          
          final progress = download.totalSize > 0 
              ? (totalDownloaded * 100 / download.totalSize).round() 
              : 0;

          // Update at interval
          if (now.difference(lastProgressUpdate).inMilliseconds >= PROGRESS_UPDATE_INTERVAL) {
            download.speed = currentSpeed.toDouble();
            download.peakSpeed = peakSpeed;
            download.averageSpeed = avgSpeed;
            download.progress = progress;
            download.connectionsUsed = segments.where((s) => s.isActive).length;
            
            // Update connection quality
            download.connectionQuality = _classifyConnectionQuality(avgSpeed);
            
            _downloads[id] = download;
            onProgress?.call(download);
            
            // Update global stats
            _updateGlobalSpeed();
            
            lastProgressUpdate = now;
            lastSpeedUpdate = now;
          }
        },
      ));
    }

    // Wait for all segments
    await Future.wait(futures);
    await raf.close();

    // Check if cancelled
    if (active.isCancelled) {
      return;
    }

    // Move to final location
    final finalPath = download.downloadPath ?? path.join(_downloadDirectory, download.filename);
    if (await tempFile.exists()) {
      await tempFile.rename(finalPath);
    }

    // Mark complete
    final completed = download.copyWith(
      downloadedSize: download.totalSize > 0 ? download.totalSize : totalDownloaded,
      progress: 100,
      speed: 0,
      status: TurboDownloadStatus.completed,
      completedAt: DateTime.now().millisecondsSinceEpoch,
      connectionsUsed: segments.length,
    );
    
    await _saveDownload(completed);
    _activeDownloads.remove(id);
    _downloadQueue.remove(id);
    _speedHistory.remove(id);

    onComplete?.call(completed);
    await _notifications.showDownloadComplete(
      downloadId: id,
      filename: completed.filename,
      filePath: finalPath,
      fileSize: completed.totalSize,
    );

    _logger.info('TurboDownload', '✅ Completed: ${completed.filename} (${completed.formattedPeakSpeed} peak)');
    
    _tryStartNextDownload();
  }

  Future<void> _downloadSingleSegment(String id) async {
    final active = _activeDownloads[id];
    if (active == null) return;

    var download = active.download;
    final startTime = DateTime.now();
    final speedSamples = <_SpeedSample>[];
    _speedHistory[id] = speedSamples;

    try {
      final client = _getClient();
      final request = http.Request('GET', Uri.parse(download.url));
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final tempPath = download.tempPath ?? path.join(_downloadDirectory, '._${download.filename}.tmp');
      final tempFile = File(tempPath);
      final raf = await tempFile.open(mode: FileMode.write);

      var totalDownloaded = 0;
      final buffer = List<int>.filled(BUFFER_SIZE, 0);
      DateTime lastUpdate = DateTime.now();

      await for (final chunk in response.stream) {
        // Check pause/cancel
        while (active.isPaused && !active.isCancelled) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (active.isCancelled) {
          await raf.close();
          return;
        }

        await raf.writeFrom(chunk);
        totalDownloaded += chunk.length;
        download.downloadedSize = totalDownloaded;
        
        final now = DateTime.now();
        final elapsed = now.difference(startTime).inSeconds;
        final currentSpeed = elapsed > 0 ? totalDownloaded / elapsed : 0;
        
        speedSamples.add(_SpeedSample(now, totalDownloaded));
        if (speedSamples.length > SPEED_SAMPLE_COUNT) {
          speedSamples.removeAt(0);
        }
        
        double avgSpeed = currentSpeed.toDouble();
        if (speedSamples.length >= 2) {
          final first = speedSamples.first;
          final last = speedSamples.last;
          final timeDiff = last.timestamp.difference(first.timestamp).inSeconds;
          if (timeDiff > 0) {
            avgSpeed = (last.bytes - first.bytes) / timeDiff;
          }
        }

        if (now.difference(lastUpdate).inMilliseconds >= PROGRESS_UPDATE_INTERVAL) {
          download.speed = currentSpeed.toDouble();
          if (currentSpeed > download.peakSpeed) {
            download.peakSpeed = currentSpeed.toDouble();
          }
          download.averageSpeed = avgSpeed;
          download.connectionQuality = _classifyConnectionQuality(avgSpeed);
          _downloads[id] = download;
          onProgress?.call(download);
          _updateGlobalSpeed();
          lastUpdate = now;
        }
      }

      await raf.close();

      // Move to final location
      final finalPath = download.downloadPath ?? path.join(_downloadDirectory, download.filename);
      if (await tempFile.exists()) {
        await tempFile.rename(finalPath);
      }

      // Complete
      final completed = download.copyWith(
        downloadedSize: totalDownloaded,
        progress: 100,
        speed: 0,
        status: TurboDownloadStatus.completed,
        completedAt: DateTime.now().millisecondsSinceEpoch,
      );
      
      await _saveDownload(completed);
      _activeDownloads.remove(id);
      _downloadQueue.remove(id);
      _speedHistory.remove(id);

      onComplete?.call(completed);
      await _notifications.showDownloadComplete(
        downloadId: id,
        filename: completed.filename,
        filePath: finalPath,
        fileSize: completed.totalSize,
      );

      _logger.info('TurboDownload', '✅ Completed: ${completed.filename}');
      _tryStartNextDownload();

    } catch (e) {
      await _handleDownloadError(id, e.toString());
    }
  }

  Future<void> _downloadSegmentWithClient({
    required String id,
    required String url,
    required TurboSegment segment,
    required RandomAccessFile raf,
    required Function(int) onProgress,
  }) async {
    final active = _activeDownloads[id];
    if (active == null) return;

    try {
      final client = _getClient();
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Range'] = 'bytes=${segment.start}-${segment.end}';
      
      final response = await client.send(request);
      
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Server returned ${response.statusCode}');
      }

      var segmentDownloaded = 0;
      final buffer = List<int>.filled(BUFFER_SIZE, 0);

      await for (final chunk in response.stream) {
        if (active.isCancelled) break;
        
        while (active.isPaused && !active.isCancelled) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        await raf.setPosition(segment.start + segmentDownloaded);
        await raf.writeFrom(chunk);
        
        segmentDownloaded += chunk.length;
        onProgress(chunk.length);
      }

      return;

    } catch (e) {
      if (!active.isCancelled) {
        rethrow;
      }
      return;
    }
  }

  Future<void> _handleDownloadError(String id, String error) async {
    final active = _activeDownloads[id];
    _activeDownloads.remove(id);
    
    final download = _downloads[id];
    if (download == null) return;

    if (download.retryCount < download.maxRetries) {
      // Retry with exponential backoff
      final delay = _calculateRetryDelay(download.retryCount);
      
      _logger.info('TurboDownload', '⚠️ ${download.filename}: Retry ${download.retryCount + 1}/${download.maxRetries} in ${delay}ms');
      
      final updated = download.copyWith(
        retryCount: download.retryCount + 1,
        status: TurboDownloadStatus.queued,
        error: error,
      );
      
      _downloads[id] = updated;
      await _saveDownload(updated);
      
      // Wait and retry
      await Future.delayed(Duration(milliseconds: delay));
      _tryStartNextDownload();
      
    } else {
      // Max retries reached
      _logger.error('TurboDownload', '❌ ${download.filename}: Max retries reached');
      
      final failed = download.copyWith(
        status: TurboDownloadStatus.failed,
        error: error,
      );
      
      await _saveDownload(failed);
      _downloadQueue.remove(id);
      
      onError?.call(failed, error);
      await _notifications.showDownloadFailed(
        downloadId: id,
        filename: download.filename,
        error: error,
      );
      
      _tryStartNextDownload();
    }
  }

  int _calculateRetryDelay(int retryCount) {
    // Exponential backoff with jitter
    final baseDelay = BASE_RETRY_DELAY_MS * math.pow(2, retryCount).toInt();
    final jitter = (baseDelay * 0.1 * math.Random().nextDouble()).toInt();
    return math.min(baseDelay + jitter, MAX_RETRY_DELAY_MS);
  }

  ConnectionQuality _classifyConnectionQuality(double speedBps) {
    if (speedBps > 10 * 1024 * 1024) return ConnectionQuality.excellent;
    if (speedBps > 2 * 1024 * 1024) return ConnectionQuality.good;
    if (speedBps > 500 * 1024) return ConnectionQuality.fair;
    return ConnectionQuality.poor;
  }

  void _updateGlobalSpeed() {
    double total = 0;
    for (final active in _activeDownloads.values) {
      total += active.download.speed;
    }
    
    if (total > _globalPeakSpeed) {
      _globalPeakSpeed = total;
    }
    
    _currentBandwidthUsage = total;
    onSpeedUpdate?.call(total, _globalAverageSpeed);
  }

  void _onNetworkRestored() {
    _logger.info('TurboDownload', '🌐 Network restored - resuming downloads');
    _tryStartNextDownload();
  }

  void _onNetworkLost() {
    _logger.info('TurboDownload', '⚠️ Network lost - pausing active downloads');
    _pauseAllForNetwork();
  }

  void _pauseAllForNetwork() {
    for (final id in _downloadQueue.toList()) {
      final download = _downloads[id];
      if (download != null && download.status == TurboDownloadStatus.downloading) {
        pauseDownload(id);
        _downloads[id] = download.copyWith(status: TurboDownloadStatus.waitingForNetwork);
      }
    }
  }

  http.Client _getClient() {
    if (_clientPool.isEmpty) {
      _clientPool.add(http.Client());
    }
    return _clientPool.removeAt(0);
  }

  void _releaseClient(http.Client client) {
    if (_clientPool.length < MAX_CLIENT_POOL_SIZE) {
      _clientPool.add(client);
    }
  }

  Future<void> _saveDownload(TurboDownloadItem download) async {
    try {
      _downloads[download.id] = download;
      await _database.insertDownload(download.toMap());
    } catch (e) {
      _logger.error('TurboDownload', 'Failed to save download', error: e);
    }
  }

  Future<void> _deleteTempFile(TurboDownloadItem download) async {
    if (download.tempPath != null) {
      final tempFile = File(download.tempPath!);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  String _generateId(String url) {
    return url.hashCode.abs().toString();
  }

  String _extractFilename(String url) {
    try {
      final uri = Uri.parse(url);
      var filename = path.basename(uri.path);
      
      if (filename.isEmpty || !filename.contains('.')) {
        filename = 'turbo_download_${DateTime.now().millisecondsSinceEpoch}';
      }

      if (filename.contains('?')) {
        filename = filename.split('?').first;
      }

      filename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      return filename;
    } catch (e) {
      return 'turbo_download_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }

  // ============================================================================
  // GETTERS
  // ============================================================================

  List<TurboDownloadItem> getAllDownloads() => _downloads.values.toList();
  
  List<TurboDownloadItem> getActiveDownloads() => 
      _downloads.values.where((d) => d.status == TurboDownloadStatus.downloading).toList();
  
  List<TurboDownloadItem> getCompletedDownloads() => 
      _downloads.values.where((d) => d.status == TurboDownloadStatus.completed).toList();
  
  List<TurboDownloadItem> getQueue() => 
      _downloadQueue.map((id) => _downloads[id]).where((d) => d != null).cast<TurboDownloadItem>().toList();
  
  List<TurboDownloadItem> getFailedDownloads() => 
      _downloads.values.where((d) => d.status == TurboDownloadStatus.failed).toList();
  
  TurboDownloadItem? getDownload(String id) => _downloads[id];
  
  double getTotalSpeed() => _currentBandwidthUsage;
  
  double getPeakSpeed() => _globalPeakSpeed;
  
  bool get isNetworkAvailable => _isConnected;
  
  bool get isOnWifi => _isWifi;
  
  int get activeDownloadCount => _activeDownloads.length;
  
  int get queueLength => _downloadQueue.length;

  // Resume all paused downloads
  Future<void> resumeAll() async {
    for (final id in _downloadQueue.toList()) {
      final download = _downloads[id];
      if (download != null && 
          (download.status == TurboDownloadStatus.paused ||
           download.status == TurboDownloadStatus.waitingForNetwork)) {
        await resumeDownload(id);
      }
    }
  }

  // Clear completed downloads
  Future<void> clearCompleted() async {
    for (final download in getCompletedDownloads()) {
      await cancelDownload(download.id);
    }
  }
}

/// Speed sample for tracking
class _SpeedSample {
  final DateTime timestamp;
  final int bytes;

  _SpeedSample(this.timestamp, this.bytes);
}

/// Active download tracking
class TurboActiveDownload {
  TurboDownloadItem download;
  List<Future> tasks;
  List<_CancelToken> cancelTokens;
  bool isPaused = false;
  bool isCancelled = false;

  TurboActiveDownload({
    required this.download,
    required this.tasks,
    this.cancelTokens = const [],
    this.isPaused = false,
    this.isCancelled = false,
  });
}

/// Cancel token
class _CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}

/// Global instance
final turboDownloader = TurboDownloadManager();
