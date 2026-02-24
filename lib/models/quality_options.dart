class VideoQuality {
  final String label;
  final String resolution;
  final int bitrate;
  final String? extension;

  const VideoQuality({
    required this.label,
    required this.resolution,
    required this.bitrate,
    this.extension,
  });

  static const List<VideoQuality> qualities = [
    VideoQuality(label: '4K (Ultra HD)', resolution: '3840x2160', bitrate: 25000, extension: 'mp4'),
    VideoQuality(label: '1080p (Full HD)', resolution: '1920x1080', bitrate: 8000, extension: 'mp4'),
    VideoQuality(label: '720p (HD)', resolution: '1280x720', bitrate: 5000, extension: 'mp4'),
    VideoQuality(label: '480p (SD)', resolution: '854x480', bitrate: 2500, extension: 'mp4'),
    VideoQuality(label: '360p', resolution: '640x360', bitrate: 1000, extension: 'mp4'),
    VideoQuality(label: '240p', resolution: '426x240', bitrate: 400, extension: 'mp4'),
  ];
}

class AudioQuality {
  final String label;
  final int bitrate;

  const AudioQuality({
    required this.label,
    required this.bitrate,
  });

  static const List<AudioQuality> qualities = [
    AudioQuality(label: '320 kbps', bitrate: 320),
    AudioQuality(label: '256 kbps', bitrate: 256),
    AudioQuality(label: '192 kbps', bitrate: 192),
    AudioQuality(label: '128 kbps', bitrate: 128),
    AudioQuality(label: '96 kbps', bitrate: 96),
    AudioQuality(label: '64 kbps', bitrate: 64),
  ];
}
