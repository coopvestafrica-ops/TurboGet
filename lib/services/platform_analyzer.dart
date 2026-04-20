import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

enum PlatformType {
  youtube,
  amazon,
  vimeo,
  dailymotion,
  general,
}

/// A selectable video quality returned by [PlatformAnalyzer.getVideoQualities].
///
/// Named `PlatformVideoQuality` to avoid clashing with the unrelated
/// `VideoQuality` in `models/quality_options.dart` which describes a
/// different UI-facing concept.
class PlatformVideoQuality {
  final String url;
  final String quality;
  final int? width;
  final int? height;
  final String format;
  final int? bitrate;
  final int? fileSize;

  const PlatformVideoQuality({
    required this.url,
    required this.quality,
    this.width,
    this.height,
    required this.format,
    this.bitrate,
    this.fileSize,
  });
}

/// Detects the platform a URL belongs to and extracts video metadata /
/// available qualities.
///
/// Owns a lazily-created [YoutubeExplode] client. The client is reused
/// across calls; callers should invoke [dispose] when the analyzer is no
/// longer needed. A previous revision closed the client after every call,
/// making subsequent extractions fail.
class PlatformAnalyzer {
  YoutubeExplode? _yt;

  YoutubeExplode get _client => _yt ??= YoutubeExplode();

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

  Future<List<PlatformVideoQuality>> getVideoQualities(String url) async {
    final platform = await detectPlatform(url);

    switch (platform) {
      case PlatformType.youtube:
        return _getYoutubeQualities(url);
      case PlatformType.vimeo:
        return _getVimeoQualities(url);
      case PlatformType.dailymotion:
        return _getDailymotionQualities(url);
      default:
        throw UnsupportedError('Platform not supported for quality extraction');
    }
  }

  Future<List<PlatformVideoQuality>> _getYoutubeQualities(String url) async {
    final video = await _client.videos.get(url);
    final manifest = await _client.videos.streamsClient.getManifest(video.id);

    final qualities = <PlatformVideoQuality>[];

    for (final stream in manifest.videoOnly) {
      qualities.add(PlatformVideoQuality(
        url: stream.url.toString(),
        quality: '${stream.videoQuality.name} (video only)',
        width: stream.videoResolution.width,
        height: stream.videoResolution.height,
        format: stream.container.name,
        bitrate: stream.bitrate.bitsPerSecond,
        fileSize: stream.size.totalBytes,
      ));
    }

    for (final stream in manifest.muxed) {
      qualities.add(PlatformVideoQuality(
        url: stream.url.toString(),
        quality: '${stream.videoQuality.name} (with audio)',
        width: stream.videoResolution.width,
        height: stream.videoResolution.height,
        format: stream.container.name,
        bitrate: stream.bitrate.bitsPerSecond,
        fileSize: stream.size.totalBytes,
      ));
    }

    for (final stream in manifest.audioOnly) {
      qualities.add(PlatformVideoQuality(
        url: stream.url.toString(),
        quality: 'Audio ${stream.bitrate.kiloBitsPerSecond}kbps',
        format: stream.container.name,
        bitrate: stream.bitrate.bitsPerSecond,
        fileSize: stream.size.totalBytes,
      ));
    }

    return qualities;
  }

  Future<List<PlatformVideoQuality>> _getVimeoQualities(String url) async {
    throw UnimplementedError('Vimeo support coming soon');
  }

  Future<List<PlatformVideoQuality>> _getDailymotionQualities(
      String url) async {
    throw UnimplementedError('Dailymotion support coming soon');
  }

  Future<Map<String, dynamic>> getVideoMetadata(String url) async {
    final platform = await detectPlatform(url);

    switch (platform) {
      case PlatformType.youtube:
        return _getYoutubeMetadata(url);
      case PlatformType.vimeo:
        return _getVimeoMetadata(url);
      case PlatformType.dailymotion:
        return _getDailymotionMetadata(url);
      default:
        return _getGeneralMetadata(url);
    }
  }

  Future<Map<String, dynamic>> _getYoutubeMetadata(String url) async {
    final video = await _client.videos.get(url);
    return {
      'title': video.title,
      'author': video.author,
      'duration': video.duration?.inSeconds ?? 0,
      'thumbnailUrl': video.thumbnails.highResUrl,
      'description': video.description,
      'platform': 'YouTube',
    };
  }

  Future<Map<String, dynamic>> _getVimeoMetadata(String url) async {
    throw UnimplementedError('Vimeo support coming soon');
  }

  Future<Map<String, dynamic>> _getDailymotionMetadata(String url) async {
    throw UnimplementedError('Dailymotion support coming soon');
  }

  Future<Map<String, dynamic>> _getGeneralMetadata(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return {'title': url.split('/').last, 'platform': 'General'};
      }
      final document = parser.parse(response.body);
      final title =
          document.querySelector('title')?.text.trim() ?? url.split('/').last;
      return {
        'title': title,
        'platform': 'General',
      };
    } catch (_) {
      return {'title': url.split('/').last, 'platform': 'General'};
    }
  }

  /// Releases the YoutubeExplode client. Call from the owning widget's
  /// dispose method; further calls will recreate the client on demand.
  void dispose() {
    _yt?.close();
    _yt = null;
  }
}
