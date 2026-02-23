import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/download_item.dart';
import '../models/download_state.dart';

/// Represents an HTTP response header section
class HttpResponseHeader {
  final int statusCode;
  final String statusMessage;
  final Map<String, String> headers;
  
  const HttpResponseHeader({
    required this.statusCode,
    required this.statusMessage,
    required this.headers,
  });

  bool get isPartialContent => statusCode == 206;
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get acceptsRanges => headers['accept-ranges']?.toLowerCase() == 'bytes';
  
  int? get contentLength {
    final lengthStr = headers['content-length'];
    return lengthStr != null ? int.tryParse(lengthStr) : null;
  }

  @override
  String toString() => 'HTTP $statusCode $statusMessage';
}

/// A downloader that supports segmented parallel downloads
class TurboDownloader {
  /// Maximum number of concurrent connections per download
  static const int maxConcurrentConnections = 16;
  
  /// Minimum segment size for partial downloads (1MB)
  static const int minSegmentSize = 1024 * 1024;
  
  /// Buffer size for optimal disk writes (64KB)
  static const int bufferSize = 64 * 1024;
  
  /// Maximum size for HTTP headers (32KB)
  static const int maxHeaderSize = 32 * 1024;
  
  /// Interval for speed updates
  static const Duration speedUpdateInterval = Duration(milliseconds: 500);

  /// Active socket connections for each download
  final Map<String, Set<Socket>> _activeSockets = {};
  
  /// Progress update controllers for each download
  final Map<String, StreamController<DownloadProgress>> _progressControllers = {};
  
  /// Last recorded bytes downloaded for speed calculation
  final Map<String, int> _lastBytesDownloaded = {};
  
  /// Last speed check timestamp for each download
  final Map<String, DateTime> _lastSpeedCheck = {};
  
  /// Current download speeds in MB/s
  final Map<String, double> _currentSpeeds = {};
  
  /// Segment ranges for each download
  final Map<String, List<SegmentRange>> _segments = {};
  
  /// Progress tracking for each segment
  final Map<String, Map<int, int>> _segmentProgress = {};
  
  /// Status tracking for each segment
  final Map<String, Map<int, String>> _segmentStatus = {};

  /// Downloads a file with segmented parallel connections, providing progress updates.
  /// 
  /// Args:
  ///   item: The DownloadItem containing file details
  ///   resumeState: Optional state to resume a previous download
  ///
  /// Returns a Stream of DownloadProgress updates.
  Stream<DownloadProgress> downloadFile(DownloadItem item, {DownloadState? resumeState}) {
    final progressController = StreamController<DownloadProgress>.broadcast();
    
    // Initialize download state
    _progressControllers[item.id] = progressController;
    _lastBytesDownloaded[item.id] = 0;
    _lastSpeedCheck[item.id] = DateTime.now();
    _segmentProgress[item.id] = {};
    _segmentStatus[item.id] = {};

    // Start download in background
    _startDownload(item, progressController).catchError((error) {
      progressController.addError(error);
      return null;
    });

    return progressController.stream;
  }

  Future<void> _startDownload(
    DownloadItem item,
    StreamController<DownloadProgress> progressController,
  ) async {
    RandomAccessFile? raf;
    File? tempFile;
    
  try {
    // Get file metadata and verify range support
    final metadata = await _getFileMetadata(item.url);
    if (!metadata.supportsRanges) {
      throw Exception('Server does not support range requests for turbo download');
    }

    // Calculate segments
    final segmentSize = _calculateOptimalSegmentSize(metadata.fileSize);
    final segments = _createSegments(metadata.fileSize, segmentSize);
    _segments[item.id] = segments;

    // Setup temp file
    final tempPath = await _createTempFile(item.filename);
    tempFile = File(tempPath);
    await tempFile.create(recursive: true);
    
    // Pre-allocate file size using RandomAccessFile
    raf = await tempFile.open(mode: FileMode.write);
    await raf.truncate(metadata.fileSize);
    
    // Zero-fill to ensure space allocation
    final zeros = Uint8List(bufferSize);
    var pos = 0;
    while (pos < metadata.fileSize) {
      final writeSize = min(bufferSize, metadata.fileSize - pos);
      await raf.writeFrom(zeros, 0, writeSize);
      pos += writeSize;
    }
    await raf.close();
    raf = null;

    // Start segment downloads
    final futures = <Future>[];
    _activeSockets[item.id] = <Socket>{};

    for (var segment in segments) {
      if (futures.length >= maxConcurrentConnections) {
        await Future.any(futures); // Wait for a slot to become available
      }

      final future = _downloadSegment(
        item.id,
        item.url,
        segment,
        tempFile.path,
        metadata.fileSize,
        progressController,
      );
      futures.add(future);
    }

    try {
      // Wait for all segments to complete
      await Future.wait(futures);

      // Verify file integrity
      final downloadedSize = await tempFile.length();
      if (downloadedSize != metadata.fileSize) {
        throw Exception('Download incomplete: size mismatch');
      }

      // Move to final location
      final destPath = await _getFinalPath(item.filename);
      await tempFile.rename(destPath);

      // Send completion progress update
      progressController.add(DownloadProgress(
        id: item.id,
        totalBytes: metadata.fileSize,
        downloadedBytes: metadata.fileSize,
        speed: 0,
        isComplete: true,
      ));

    } finally {
      // Always attempt to clean up resources
      try {
        if (raf != null) {
          await raf.close();
        }
      } catch (e) {
        debugPrint('Error closing file: $e');
      }
      
      // Clean up state maps
      _cleanupDownload(item.id);
      
      // Cancel any lingering sockets
      final sockets = _activeSockets[item.id];
      if (sockets != null) {
        for (final socket in sockets) {
          try {
            socket.destroy();
          } catch (e) {
            debugPrint('Error destroying socket: $e');
          }
        }
      }

      // Remove temp file if it still exists
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint('Error cleaning up temp file: $e');
      }
    }
  } catch (e) {
    progressController.addError(e);
  }
  }

  /// Downloads a single segment of the file
  Future<void> _downloadSegment(
    String id,
    String url,
    SegmentRange segment,
    String filePath,
    int totalSize,
    StreamController<DownloadProgress> progressController,
  ) async {
    Socket? socket;
    RandomAccessFile? raf;
    
    try {
      // Parse URL and setup connection
      final uri = Uri.parse(url);
      final port = uri.port == 0 ? (uri.scheme == 'https' ? 443 : 80) : uri.port;
      
      // Connect with appropriate socket type
      socket = await (uri.scheme == 'https' 
          ? SecureSocket.connect(uri.host, port,
              onBadCertificate: (cert) => true) // TODO: Proper cert validation
          : Socket.connect(uri.host, port));

      final sockets = _activeSockets[id];
      if (sockets != null) {
        sockets.add(socket);
      } else {
        _activeSockets[id] = {socket};
      }
      
      // Prepare file access
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Download file no longer exists: $filePath');
      }
      
      raf = await file.open(mode: FileMode.write);
      await raf.setPosition(segment.start);

      // Send HTTP request with range
      final request = StringBuffer ()
        ..writeln('GET ${uri.path}${uri.query.isEmpty ? '' : '?${uri.query}'} HTTP/1.1')
        ..writeln('Host: ${uri.host}')
        ..writeln('Range: bytes=${segment.start}-${segment.end}')
        ..writeln('Connection: close')
        ..writeln('Accept: */*')
        ..writeln();
      
      socket.write(request.toString());

      // Setup header parsing
      var isHeader = true;
      var headerBytes = <int>[];
      var downloadedBytes = 0;
      _segmentStatus[id] ??= {};

      // Process incoming data
      await for (final chunk in socket) {
        if (isHeader) {
          // Check header size limit
          if (headerBytes.length + chunk.length > maxHeaderSize) {
            throw Exception('HTTP header too large (exceeds $maxHeaderSize bytes)');
          }

          // Collect header bytes until we find the end
          headerBytes.addAll(chunk);
          final (headerEndPos, bodyStartPos) = _findHeaderEnd(headerBytes);
          
          if (headerEndPos != -1) {
            // Parse headers and validate response
            final headers = _parseHeaders(headerBytes.sublist(0, headerEndPos));
            
            if (!headers.isPartialContent) {
              throw Exception('Server did not accept range request: $headers');
            }

            // Verify content length if server provided it
            if (headers.contentLength != null && headers.contentLength != segment.length) {
              throw Exception(
                'Server returned wrong content length: '
                'expected ${segment.length}, got ${headers.contentLength}'
              );
            }
            
            // Process body data after header
            if (bodyStartPos < headerBytes.length) {
              final bodyData = headerBytes.sublist(bodyStartPos);
              await raf.writeFrom(bodyData);
              downloadedBytes += bodyData.length;
            }
            
            isHeader = false;
            headerBytes.clear(); // Free memory
            _segmentStatus[id]![segment.start] = 'downloading';
          }
          continue;
        }

        // Write chunk and update progress
        await raf.writeFrom(chunk);
        downloadedBytes += chunk.length;
        
        // Track segment progress
        _segmentProgress[id] ??= {};
        _segmentProgress[id]![segment.start] = downloadedBytes;

        // Update overall progress
        _updateProgress(
          id,
          downloadedBytes,
          segment.length,
          totalSize,
          progressController,
        );
      }

      // Verify segment completion
      if (downloadedBytes != segment.length) {
        throw Exception('Segment download incomplete: $downloadedBytes != ${segment.length}');
      }
      
      _segmentStatus[id]![segment.start] = 'completed';
      await raf.flush();
      await raf.close();
      raf = null;
    } catch (e) {
      _segmentStatus[id]?[segment.start] = 'failed';
      rethrow;
    } finally {
      // Cleanup resources in order
      try {
        if (raf != null) {
          await raf.close();
        }
      } catch (e) {
        debugPrint('Error closing file: $e');
      }

      try {
        if (socket != null) {
          socket.destroy();
          _activeSockets[id]?.remove(socket);
        }
      } catch (e) {
        debugPrint('Error cleaning up socket: $e');
      }
    }
  }

  /// Updates download progress and speed calculations using a moving average
  void _updateProgress(
    String id,
    int segmentBytes,
    int segmentTotal,
    int fileTotal,
    StreamController<DownloadProgress> controller,
  ) {
    final now = DateTime.now();
    final lastCheck = _lastSpeedCheck[id] ?? now;
    final elapsed = now.difference(lastCheck).inMilliseconds;

    // Calculate total progress across all segments
    final totalDownloaded = _segmentProgress[id]?.values.fold<int>(
          0, (sum, bytes) => sum + bytes) ?? 0;

    // Only update speed calculation periodically
    if (elapsed >= speedUpdateInterval.inMilliseconds) {
      final lastBytes = _lastBytesDownloaded[id] ?? 0;
      final byteDiff = totalDownloaded - lastBytes;
      
      if (byteDiff > 0 && elapsed > 0) {
        // Calculate instantaneous speed
        final instantSpeedMBps = (byteDiff / elapsed * 1000) / (1024 * 1024);
        
        // Use exponential moving average for smoother speed updates
        final currentSpeed = _currentSpeeds[id] ?? 0.0;
        final alpha = 0.3; // Smoothing factor (0.0-1.0)
        final smoothedSpeed = (alpha * instantSpeedMBps) + ((1 - alpha) * currentSpeed);
        
        // Update tracking with smoothed speed
        _currentSpeeds[id] = smoothedSpeed;
        _lastBytesDownloaded[id] = totalDownloaded;
        _lastSpeedCheck[id] = now;

        // Emit progress update with smoothed speed
        controller.add(DownloadProgress(
          id: id,
          totalBytes: fileTotal,
          downloadedBytes: totalDownloaded,
          speed: smoothedSpeed,
          isComplete: totalDownloaded >= fileTotal,
        ));
      } else {
        // No progress since last check, emit update without speed
        controller.add(DownloadProgress(
          id: id,
          totalBytes: fileTotal,
          downloadedBytes: totalDownloaded,
          speed: 0.0,
          isComplete: totalDownloaded >= fileTotal,
        ));
      }
    }
  }

  /// Cancels an active download
  void cancelDownload(String id) {
    // Close all active sockets
    final sockets = _activeSockets[id];
    if (sockets != null) {
      for (var socket in sockets) {
        socket.destroy();
      }
    }

    // Mark all segments as cancelled
    final segments = _segments[id];
    if (segments != null) {
      for (var segment in segments) {
        _segmentStatus[id]?[segment.start] = 'cancelled';
      }
    }

    _cleanupDownload(id);
  }

  /// Cleans up resources for a download
  void _cleanupDownload(String id) {
    _activeSockets.remove(id);
    _progressControllers.remove(id);
    _lastBytesDownloaded.remove(id);
    _lastSpeedCheck.remove(id);
    _currentSpeeds.remove(id);
    _segments.remove(id);
    _segmentProgress.remove(id);
    _segmentStatus.remove(id);
  }

  List<SegmentState> getSegmentStates(String id) {
    // Convert current segment progress to SegmentState objects
    final states = <SegmentState>[];
    final segments = _segments[id];
    if (segments != null) {
      for (var segment in segments) {
        states.add(SegmentState(
          start: segment.start,
          end: segment.end,
          downloadedBytes: _getSegmentProgress(id, segment),
          status: _getSegmentStatus(id, segment),
        ));
      }
    }
    return states;
  }

  int _getSegmentProgress(String id, SegmentRange segment) {
    // Get the current progress for a segment
    final progress = _segmentProgress[id]?[segment.start];
    return progress ?? 0;
  }

  String _getSegmentStatus(String id, SegmentRange segment) {
    // Get the current status for a segment
    final status = _segmentStatus[id]?[segment.start];
    return status ?? 'pending';
  }

  int _calculateOptimalSegmentSize(int fileSize) {
    // Calculate optimal segment size based on file size
    // Larger files get larger segments to reduce overhead
    if (fileSize < 50 * 1024 * 1024) { // < 50MB
      return minSegmentSize;
    } else if (fileSize < 200 * 1024 * 1024) { // < 200MB
      return 2 * minSegmentSize;
    } else if (fileSize < 1024 * 1024 * 1024) { // < 1GB
      return 4 * minSegmentSize;
    } else {
      return 8 * minSegmentSize;
    }
  }

  List<SegmentRange> _createSegments(int fileSize, int segmentSize) {
    final segments = <SegmentRange>[];
    var start = 0;
    while (start < fileSize) {
      final end = start + segmentSize - 1;
      segments.add(SegmentRange(
        start: start,
        end: end >= fileSize ? fileSize - 1 : end,
      ));
      start = end + 1;
    }
    return segments;
  }

  /// Finds the end of HTTP headers (double CRLF) in a byte buffer.
  /// Returns a tuple of (headerEnd, bodyStart) or (-1, -1) if not found.
  (int, int) _findHeaderEnd(List<int> buffer) {
    // Find double CRLF
    for (var i = 0; i < buffer.length - 3; i++) {
      if (buffer[i] == 13 && buffer[i + 1] == 10 && 
          buffer[i + 2] == 13 && buffer[i + 3] == 10) {
        return (i, i + 4);
      }
    }
    return (-1, -1);
  }

  /// Parse HTTP response headers from a byte buffer.
  /// Throws FormatException if headers are malformed.
  HttpResponseHeader _parseHeaders(List<int> headerBytes) {
    // Decode header bytes to string, normalizing line endings
    final headerStr = ascii.decode(headerBytes).replaceAll('\r\n', '\n');
    final lines = headerStr.split('\n');
    
    if (lines.isEmpty) {
      throw FormatException('Empty HTTP response');
    }

    // Parse status line
    final statusLine = lines[0];
    final statusMatch = RegExp(r'^HTTP/\d\.\d (\d{3}) (.*)$').firstMatch(statusLine);
    if (statusMatch == null) {
      throw FormatException('Invalid HTTP status line: $statusLine');
    }

    final statusCode = int.parse(statusMatch.group(1)!);
    final statusMessage = statusMatch.group(2)!;

    // Parse headers
    final headers = <String, String>{};
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) {
        throw FormatException('Invalid header line: $line');
      }

      final name = line.substring(0, colonIndex).trim().toLowerCase();
      final value = line.substring(colonIndex + 1).trim();
      
      // Handle multi-line headers
      if (headers.containsKey(name)) {
        headers[name] = '${headers[name]}, $value';
      } else {
        headers[name] = value;
      }
    }

    return HttpResponseHeader(
      statusCode: statusCode,
      statusMessage: statusMessage,
      headers: headers,
    );
  }

  Future<FileMetadata> _getFileMetadata(String url) async {
    Socket? socket;
    final uri = Uri.parse(url);
    final port = uri.port == 0 ? (uri.scheme == 'https' ? 443 : 80) : uri.port;
    
    try {
      socket = await (uri.scheme == 'https'
          ? SecureSocket.connect(uri.host, port, 
              onBadCertificate: (cert) => true) // TODO: Proper cert validation
          : Socket.connect(uri.host, port));

      final request = StringBuffer()
        ..writeln('HEAD ${uri.path}${uri.query.isEmpty ? '' : '?${uri.query}'} HTTP/1.1')
        ..writeln('Host: ${uri.host}')
        ..writeln('Connection: close')
        ..writeln();

      socket.write(request.toString());

      // Collect response with timeout
      final responseBytes = <int>[];
      final completer = Completer<void>();
      
      socket.listen(
        (data) {
          responseBytes.addAll(data);
          if (responseBytes.length > maxHeaderSize) {
            completer.completeError(
              Exception('Response too large (exceeds $maxHeaderSize bytes)')
            );
          }
        },
        onDone: () => completer.complete(),
        onError: (e) => completer.completeError(e),
        cancelOnError: true,
      );

      // Wait for response with timeout
      await Future.any([
        completer.future,
        Future.delayed(const Duration(seconds: 10))
            .then((_) => throw TimeoutException('HEAD request timed out')),
      ]);

      // Parse headers
      final headers = _parseHeaders(responseBytes);
      
      if (!headers.isSuccess) {
        throw Exception('Server returned error: $headers');
      }

      final contentLength = headers.contentLength;
      if (contentLength == null || contentLength == 0) {
        throw Exception('Could not determine file size');
      }

      return FileMetadata(
        fileSize: contentLength,
        supportsRanges: headers.acceptsRanges,
      );

    } finally {
      socket?.destroy();
    }
  }

  Future<String> _createTempFile(String filename) async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/$filename.tmp';
  }

  Future<String> _getFinalPath(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$filename';
  }
}

class SegmentRange {
  final int start;
  final int end;
  int get length => end - start + 1;

  SegmentRange({required this.start, required this.end});
}

class FileMetadata {
  final int fileSize;
  final bool supportsRanges;

  FileMetadata({required this.fileSize, required this.supportsRanges});
}

class DownloadProgress {
  final String id;
  final int totalBytes;
  final int downloadedBytes;
  final double speed; // MB/s
  final bool isComplete;

  DownloadProgress({
    required this.id,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.speed,
    this.isComplete = false,
  });

  double get progress => downloadedBytes / totalBytes;
}