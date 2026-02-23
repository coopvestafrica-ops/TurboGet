import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class MediaInfo {
  final String url;
  final String mimeType;
  final List<VideoResolution>? videoResolutions;
  final AudioQuality? audioQuality;
  final int? fileSize;

  MediaInfo({
    required this.url,
    required this.mimeType,
    this.videoResolutions,
    this.audioQuality,
    this.fileSize,
  });

  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');
  bool get isImage => mimeType.startsWith('image/');
  bool get isDocument => mimeType.startsWith('application/') || 
                        mimeType.startsWith('text/');
}

class VideoResolution {
  final int width;
  final int height;
  final String quality; // e.g., "1080p", "720p", "480p"
  final String url;
  final int bitrate;
  final String format; // e.g., "mp4", "webm"
  final int? fileSize;

  VideoResolution({
    required this.width,
    required this.height,
    required this.quality,
    required this.url,
    required this.bitrate,
    required this.format,
    this.fileSize,
  });

  String get resolution => '${width}x$height';
  String get displayQuality => '$quality ($format)';
  String get displaySize => fileSize != null ? 
    '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB' : 'Unknown size';
}

class AudioQuality {
  final int bitrate;
  final String format; // e.g., "mp3", "aac"
  final String url;
  final int? fileSize;

  AudioQuality({
    required this.bitrate,
    required this.format,
    required this.url,
    this.fileSize,
  });

  String get displayQuality => '${(bitrate / 1000).round()}kbps $format';
  String get displaySize => fileSize != null ?
    '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB' : 'Unknown size';
}

class MediaAnalyzer {
  static final Map<String, String> _mimeTypes = {
    '.mp4': 'video/mp4',
    '.mkv': 'video/x-matroska',
    '.webm': 'video/webm',
    '.mp3': 'audio/mpeg',
    '.m4a': 'audio/mp4',
    '.wav': 'audio/wav',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.pdf': 'application/pdf',
    '.doc': 'application/msword',
    '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.txt': 'text/plain',
  };

  Future<MediaInfo> analyzeUrl(String url) async {
    final extension = path.extension(url).toLowerCase();
    var mimeType = _mimeTypes[extension] ?? 'application/octet-stream';

    // Check real MIME type from server
    try {
      final response = await http.head(Uri.parse(url));
      if (response.headers.containsKey('content-type')) {
        mimeType = response.headers['content-type']!.split(';')[0];
      }
    } catch (e) {
      debugPrint('Error getting MIME type: $e');
    }

    // For video URLs, try to get available resolutions
    List<VideoResolution>? videoResolutions;
    AudioQuality? audioQuality;
    int? fileSize;

    try {
      final response = await http.head(Uri.parse(url));
      fileSize = int.tryParse(response.headers['content-length'] ?? '');

      if (mimeType.startsWith('video/')) {
        videoResolutions = await _analyzeVideoResolutions(url);
      } else if (mimeType.startsWith('audio/')) {
        audioQuality = await _analyzeAudioQuality(url);
      }
    } catch (e) {
      debugPrint('Error analyzing media: $e');
    }

    return MediaInfo(
      url: url,
      mimeType: mimeType,
      videoResolutions: videoResolutions,
      audioQuality: audioQuality,
      fileSize: fileSize,
    );
  }

  Future<List<VideoResolution>> _analyzeVideoResolutions(String url) async {
    // This is a simplified example. In a real implementation,
    // you would use a video platform's API (like YouTube) or
    // analyze the manifest file (for HLS/DASH streams)
    
    // Example resolutions for demonstration
    return [
      VideoResolution(
        width: 1920,
        height: 1080,
        quality: '1080p',
        url: _getResolutionUrl(url, '1080p'),
        bitrate: 5000000, // 5 Mbps
        format: 'mp4',
        fileSize: null,
      ),
      VideoResolution(
        width: 1280,
        height: 720,
        quality: '720p',
        url: _getResolutionUrl(url, '720p'),
        bitrate: 2500000, // 2.5 Mbps
        format: 'mp4',
        fileSize: null,
      ),
      VideoResolution(
        width: 854,
        height: 480,
        quality: '480p',
        url: _getResolutionUrl(url, '480p'),
        bitrate: 1000000, // 1 Mbps
        format: 'mp4',
        fileSize: null,
      ),
    ];
  }

  Future<AudioQuality> _analyzeAudioQuality(String url) async {
    // Simplified example
    return AudioQuality(
      bitrate: 320000, // 320 kbps
      format: 'mp3',
      url: url,
      fileSize: null,
    );
  }

  String _getResolutionUrl(String originalUrl, String quality) {
    // In a real implementation, this would construct the URL for different
    // resolutions based on the video platform's URL pattern
    return originalUrl.replaceAll('.mp4', '_$quality.mp4');
  }
}