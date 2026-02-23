import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

enum PlatformType {
  youtube,
  amazon,
  vimeo,
  dailymotion,
  general
}

class VideoQuality {
  final String url;
  final String quality;
  final int? width;
  final int? height;
  final String format;
  final int? bitrate;
  final int? fileSize;

  VideoQuality({
    required this.url,
    required this.quality,
    this.width,
    this.height,
    required this.format,
    this.bitrate,
    this.fileSize,
  });
}

class PlatformAnalyzer {
  final _yt = YoutubeExplode();
  
  Future<PlatformType> detectPlatform(String url) async {
    final uri = Uri.parse(url);
    
    if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
      return PlatformType.youtube;
    } else if (uri.host.contains('amazon.com')) {
      return PlatformType.amazon;
    } else if (uri.host.contains('vimeo.com')) {
      return PlatformType.vimeo;
    } else if (uri.host.contains('dailymotion.com')) {
      return PlatformType.dailymotion;
    }
    
    return PlatformType.general;
  }

  Future<List<VideoQuality>> getVideoQualities(String url) async {
    final platform = await detectPlatform(url);
    
    switch (platform) {
      case PlatformType.youtube:
        return await _getYoutubeQualities(url);
      case PlatformType.vimeo:
        return await _getVimeoQualities(url);
      case PlatformType.dailymotion:
        return await _getDailymotionQualities(url);
      default:
        throw UnsupportedError('Platform not supported for quality extraction');
    }
  }

  Future<List<VideoQuality>> _getYoutubeQualities(String url) async {
    try {
      final video = await _yt.videos.get(url);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      
      final qualities = <VideoQuality>[];
      
      // Add video-only streams
      for (var stream in manifest.videoOnly) {
        qualities.add(VideoQuality(
          url: stream.url.toString(),
          quality: '${stream.videoQuality.name} (video only)',
          width: stream.videoResolution.width,
          height: stream.videoResolution.height,
          format: stream.container.name,
          bitrate: stream.bitrate.bitsPerSecond,
          fileSize: stream.size.totalBytes,
        ));
      }

      // Add muxed streams (video+audio)
      for (var stream in manifest.muxed) {
        qualities.add(VideoQuality(
          url: stream.url.toString(),
          quality: '${stream.videoQuality.name} (with audio)',
          width: stream.videoResolution.width,
          height: stream.videoResolution.height,
          format: stream.container.name,
          bitrate: stream.bitrate.bitsPerSecond,
          fileSize: stream.size.totalBytes,
        ));
      }

      // Add audio-only streams
      for (var stream in manifest.audioOnly) {
        qualities.add(VideoQuality(
          url: stream.url.toString(),
          quality: 'Audio ${stream.bitrate.kiloBitsPerSecond}kbps',
          format: stream.container.name,
          bitrate: stream.bitrate.bitsPerSecond,
          fileSize: stream.size.totalBytes,
        ));
      }

      return qualities;
    } finally {
      _yt.close();
    }
  }

  Future<List<VideoQuality>> _getVimeoQualities(String url) async {
    // Implementation for Vimeo quality extraction
    // Would require Vimeo API credentials in production
    throw UnimplementedError('Vimeo support coming soon');
  }

  Future<List<VideoQuality>> _getDailymotionQualities(String url) async {
    // Implementation for Dailymotion quality extraction
    throw UnimplementedError('Dailymotion support coming soon');
  }

  Future<Map<String, dynamic>> getVideoMetadata(String url) async {
    final platform = await detectPlatform(url);
    
    switch (platform) {
      case PlatformType.youtube:
        return await _getYoutubeMetadata(url);
      case PlatformType.vimeo:
        return await _getVimeoMetadata(url);
      case PlatformType.dailymotion:
        return await _getDailymotionMetadata(url);
      default:
        return await _getGeneralMetadata(url);
    }
  }

  Future<Map<String, dynamic>> _getYoutubeMetadata(String url) async {
    try {
      final video = await _yt.videos.get(url);
      return {
        'title': video.title,
        'author': video.author,
        'duration': video.duration?.inSeconds ?? 0,
        'thumbnailUrl': video.thumbnails.highResUrl,
        'description': video.description,
        'platform': 'YouTube',
      };
    } finally {
      _yt.close();
    }
  }

  Future<Map<String, dynamic>> _getVimeoMetadata(String url) async {
    // Implement Vimeo metadata extraction
    throw UnimplementedError('Vimeo support coming soon');
  }

  Future<Map<String, dynamic>> _getDailymotionMetadata(String url) async {
    // Implement Dailymotion metadata extraction
    throw UnimplementedError('Dailymotion support coming soon');
  }

  Future<Map<String, dynamic>> _getGeneralMetadata(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final document = parser.parse(response.body);
      
      return {
        'title': document.querySelector('title')?.text ?? 'Unknown Title',
        'platform': 'General',
      };
    } catch (e) {
      return {
        'title': 'Unknown Title',
        'platform': 'General',
      };
    }
  }

}
