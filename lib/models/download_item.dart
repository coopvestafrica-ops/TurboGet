import 'dart:convert';

/// Model representing a download.
class DownloadItem {
  final String id;
  final String url;
  final String filename;
  final int createdAt;
  int? totalSize;
  int downloadedSize;
  String status;
  int progress;
  String? downloadPath;
  List<DownloadSegment>? segments;
  String? error;
  Map<String, dynamic>? metadata;

  /// Optional SHA-256 of the expected payload, used to verify integrity
  /// when the download completes. Lower-case hex.
  String? sha256;

  /// Owning user's id. Super-admins can see every download; everyone
  /// else sees only their own.
  String? ownerUserId;

  /// Sort order in the active queue. Lower numbers run first.
  int priority;
  double _speed = 0;
  int _lastBytes = 0;
  DateTime? _lastUpdateTime;

  String get formattedSpeed {
    if (_speed == 0) return '0 KB/s';
    if (_speed < 1024) return '${_speed.toStringAsFixed(1)} B/s';
    if (_speed < 1024 * 1024) return '${(_speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(_speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get estimatedTimeRemaining {
    if (_speed == 0 || totalSize == null) return '--:--';
    final remainingBytes = totalSize! - downloadedSize;
    final seconds = (remainingBytes / _speed).round();
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  void updateSpeed(int currentBytes) {
    final now = DateTime.now();
    downloadedSize = currentBytes;
    if (_lastUpdateTime != null) {
      final duration = now.difference(_lastUpdateTime!).inSeconds;
      if (duration > 0) {
        final bytesPerSecond = (currentBytes - _lastBytes) / duration;
        _speed = bytesPerSecond;
      }
    }
    _lastBytes = currentBytes;
    _lastUpdateTime = now;
    progress = totalSize != null ? ((downloadedSize / totalSize!) * 100).round() : 0;
  }

  DownloadItem({
    required this.id,
    required this.url,
    required this.filename,
    required this.createdAt,
    this.totalSize,
    this.downloadedSize = 0,
    this.status = 'queued',
    this.progress = 0,
    this.downloadPath,
    this.segments,
    this.error,
    this.metadata,
    this.sha256,
    this.ownerUserId,
    this.priority = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'filename': filename,
      'created_at': createdAt,
      'total_size': totalSize,
      'downloaded_size': downloadedSize,
      'status': status,
      'progress': progress,
      'download_path': downloadPath,
      'segments': segments != null
          ? jsonEncode(segments!.map((s) => s.toMap()).toList())
          : null,
      'error': error,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'sha256': sha256,
      'owner_user_id': ownerUserId,
      'priority': priority,
    };
  }

  factory DownloadItem.fromMap(Map<String, dynamic> map) {
    return DownloadItem(
      id: map['id'] as String,
      url: map['url'] as String,
      filename: map['filename'] as String,
      createdAt: map['created_at'] as int,
      totalSize: map['total_size'] as int?,
      downloadedSize: (map['downloaded_size'] as int?) ?? 0,
      status: (map['status'] as String?) ?? 'queued',
      progress: (map['progress'] as int?) ?? 0,
      downloadPath: map['download_path'] as String?,
      segments: map['segments'] != null
          ? List<DownloadSegment>.from(
              (jsonDecode(map['segments'] as String) as List)
                  .map((x) => DownloadSegment.fromMap(x as Map<String, dynamic>)))
          : null,
      error: map['error'] as String?,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(jsonDecode(map['metadata'] as String))
          : null,
      sha256: map['sha256'] as String?,
      ownerUserId: map['owner_user_id'] as String?,
      priority: (map['priority'] as int?) ?? 0,
    );
  }
}

class DownloadSegment {
  int? id;
  final String downloadId;
  final int startByte;
  final int endByte;
  int downloadedBytes;
  String status;

  DownloadSegment({
    this.id,
    required this.downloadId,
    required this.startByte,
    required this.endByte,
    this.downloadedBytes = 0,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'download_id': downloadId,
      'start_byte': startByte,
      'end_byte': endByte,
      'downloaded_bytes': downloadedBytes,
      'status': status,
    };
  }

  factory DownloadSegment.fromMap(Map<String, dynamic> map) {
    return DownloadSegment(
      id: map['id'] as int?,
      downloadId: map['download_id'] as String,
      startByte: map['start_byte'] as int,
      endByte: map['end_byte'] as int,
      downloadedBytes: (map['downloaded_bytes'] as int?) ?? 0,
      status: (map['status'] as String?) ?? 'pending',
    );
  }
}
