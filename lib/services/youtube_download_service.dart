import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../services/logger_service.dart';
import '../services/best_downloader_service.dart';

/// Video quality option
class VideoQuality {
  final String label;
  final String quality;
  final String codec;
  final int bitrate;
  final int height;

  const VideoQuality({
    required this.label,
    required this.quality,
    required this.codec,
    required this.bitrate,
    required this.height,
  });

  String get resolution => '${quality}p';
}

/// YouTube download service
/// Supports video and audio extraction with quality selection
class YouTubeDownloadService {
  static final YouTubeDownloadService _instance = YouTubeDownloadService._internal();
  factory YouTubeDownloadService() => _instance;
  YouTubeDownloadService._internal();

  final LoggerService _logger = logger;
  final YoutubeExplode _yt = YoutubeExplode();
  final BestDownloaderService _downloader = bestDownloader;

  /// Check if URL is a YouTube URL
  bool isYouTubeUrl(String url) {
    final patterns = [
      RegExp(r'(youtube\.com/watch\?v=[\w-]+)'),
      RegExp(r'(youtu\.be/[\w-]+)'),
      RegExp(r'(youtube\.com/shorts/[\w-]+)'),
      RegExp(r'(youtube\.com/embed/[\w-]+)'),
      RegExp(r'(youtube\.com/live/[\w-]+)'),
    ];
    return patterns.any((p) => p.hasMatch(url));
  }

  /// Extract video ID from URL
  String? getVideoId(String url) {
    try {
      return _yt.getVideoIdFromUrl(url);
    } catch (e) {
      _logger.error('YouTubeService', 'Failed to extract video ID', error: e);
      return null;
    }
  }

  /// Get video metadata
  Future<YouTubeVideo?> getVideoInfo(String url) async {
    try {
      final videoId = getVideoId(url);
      if (videoId == null) return null;

      final video = await _yt.videos.get(videoId);
      return YouTubeVideo(
        id: video.id.value,
        title: video.title,
        description: video.description,
        duration: video.duration?.toString() ?? 'Unknown',
        thumbnailUrl: video.thumbnails.highResUrl,
        viewCount: video.engagement.viewCount,
        likeCount: video.engagement.likeCount,
        channelTitle: video.channelTitle,
        uploadDate: video.uploadDate?.toString() ?? 'Unknown',
      );
    } catch (e) {
      _logger.error('YouTubeService', 'Failed to get video info', error: e);
      return null;
    }
  }

  /// Get available video qualities
  Future<List<VideoQuality>> getAvailableQualities(String url) async {
    try {
      final videoId = getVideoId(url);
      if (videoId == null) return [];

      final manifest = await _yt.videos.getManifest(videoId);
      final qualities = <VideoQuality>[];

      // Video-only streams
      for (final stream in manifest.videoOnly) {
        qualities.add(VideoQuality(
          label: '${stream.videoQuality.label} (${stream.videoCodec})',
          quality: stream.videoQuality.label,
          codec: stream.videoCodec,
          bitrate: stream.bitrate.kiloBitsPerSecond,
          height: int.tryParse(stream.videoQuality.label.replaceAll('p', '')) ?? 0,
        ));
      }

      // Sort by height descending
      qualities.sort((a, b) => b.height.compareTo(a.height));

      // Remove duplicates
      final unique = <String, VideoQuality>{};
      for (final q in qualities) {
        unique[q.quality] = q;
      }

      return unique.values.toList();
    } catch (e) {
      _logger.error('YouTubeService', 'Failed to get qualities', error: e);
      return [];
    }
  }

  /// Get audio-only streams
  Future<List<AudioStreamInfo>> getAudioStreams(String url) async {
    try {
      final videoId = getVideoId(url);
      if (videoId == null) return [];

      final manifest = await _yt.videos.getManifest(videoId);
      return manifest.audioOnly;
    } catch (e) {
      _logger.error('YouTubeService', 'Failed to get audio streams', error: e);
      return [];
    }
  }

  /// Download video with quality selection
  Future<PersistedDownload?> downloadVideo({
    required String url,
    required VideoQuality quality,
    Function(double)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final videoId = getVideoId(url);
      if (videoId == null) {
        onError?.call('Invalid YouTube URL');
        return null;
      }

      // Get video info for filename
      final video = await _yt.videos.get(videoId);
      final filename = _sanitizeFilename(video.title) + '.mp4';

      // Get manifest
      final manifest = await _yt.videos.getManifest(videoId);

      // Find video stream with desired quality
      VideoOnlyStreamInfo? videoStream;
      for (final stream in manifest.videoOnly) {
        if (stream.videoQuality.label == quality.quality) {
          videoStream = stream;
          break;
        }
      }

      // Fallback to highest quality if exact match not found
      videoStream ??= manifest.videoOnly.firstOrNull;

      if (videoStream == null) {
        onError?.call('No video stream available');
        return null;
      }

      // Find audio stream
      final audioStream = manifest.audioOnly
          .where((s) => s.audioCodec == 'opus')
          .firstOrNull ?? manifest.audioOnly.firstOrNull;

      if (audioStream == null) {
        onError?.call('No audio stream available');
        return null;
      }

      _logger.info('YouTubeService', 'Starting download: ${video.title}');

      // Download using YouTube Explode
      final videoUrl = videoStream.url;
      final audioUrl = audioStream.url;

      // For now, we'll download video only (without muxing)
      // In production, you'd use ffmpeg to combine video and audio
      final download = await _downloader.startDownload(
        videoUrl,
        filename: filename,
      );

      return download;
    } catch (e) {
      _logger.error('YouTubeService', 'Download failed', error: e);
      onError?.call(e.toString());
      return null;
    }
  }

  /// Download audio only (MP3/AAC)
  Future<PersistedDownload?> downloadAudio({
    required String url,
    required String format,
    Function(double)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final videoId = getVideoId(url);
      if (videoId == null) {
        onError?.call('Invalid YouTube URL');
        return null;
      }

      // Get video info for filename
      final video = await _yt.videos.get(videoId);
      final ext = format == 'mp3' ? '.mp3' : '.m4a';
      final filename = _sanitizeFilename(video.title) + ext;

      // Get manifest
      final manifest = await _yt.videos.getManifest(videoId);

      // Find best audio stream
      AudioOnlyStreamInfo? audioStream;
      if (format == 'mp3' || format == 'aac') {
        audioStream = manifest.audioOnly
            .where((s) => s.audioCodec == 'opus')
            .firstOrNull ?? manifest.audioOnly.firstOrNull;
      }

      audioStream ??= manifest.audioOnly.firstOrNull;

      if (audioStream == null) {
        onError?.call('No audio stream available');
        return null;
      }

      _logger.info('YouTubeService', 'Downloading audio: ${video.title}');

      final download = await _downloader.startDownload(
        audioStream.url,
        filename: filename,
      );

      return download;
    } catch (e) {
      _logger.error('YouTubeService', 'Audio download failed', error: e);
      onError?.call(e.toString());
      return null;
    }
  }

  /// Download entire playlist
  Future<List<PersistedDownload>> downloadPlaylist({
    required String playlistUrl,
    required VideoQuality quality,
    Function(int, int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final playlist = await _yt.playlists.get(playlistUrl);
      final videos = await playlist.getVideos();
      
      final downloads = <PersistedDownload>[];
      var index = 0;
      
      for (final video in videos) {
        index++;
        onProgress?.call(index, videos.length);
        
        final download = await downloadVideo(
          url: video.url,
          quality: quality,
        );
        
        if (download != null) {
          downloads.add(download);
        }
      }
      
      return downloads;
    } catch (e) {
      _logger.error('YouTubeService', 'Playlist download failed', error: e);
      onError?.call(e.toString());
      return [];
    }
  }

  String _sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .substring(0, name.length > 100 ? 100 : name.length);
  }

  void dispose() {
    _yt.close();
  }
}

/// YouTube video metadata
class YouTubeVideo {
  final String id;
  final String title;
  final String description;
  final String duration;
  final String thumbnailUrl;
  final int viewCount;
  final int likeCount;
  final String channelTitle;
  final String uploadDate;

  YouTubeVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.thumbnailUrl,
    required this.viewCount,
    required this.likeCount,
    required this.channelTitle,
    required this.uploadDate,
  });

  String get formattedViewCount {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M views';
    }
    if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K views';
    }
    return '$viewCount views';
  }

  String get formattedLikeCount {
    if (likeCount >= 1000000) {
      return '${(likeCount / 1000000).toStringAsFixed(1)}M';
    }
    if (likeCount >= 1000) {
      return '${(likeCount / 1000).toStringAsFixed(1)}K';
    }
    return '$likeCount';
  }
}

/// Global YouTube service instance
final youtubeService = YouTubeDownloadService();