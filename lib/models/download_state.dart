

class DownloadState {
  final String id;
  final String url;
  final String filename;
  final int totalSize;
  final List<SegmentState> segments;
  final DateTime lastUpdated;

  DownloadState({
    required this.id,
    required this.url,
    required this.filename,
    required this.totalSize,
    required this.segments,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'filename': filename,
      'totalSize': totalSize,
      'segments': segments.map((s) => s.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory DownloadState.fromJson(Map<String, dynamic> json) {
    return DownloadState(
      id: json['id'],
      url: json['url'],
      filename: json['filename'],
      totalSize: json['totalSize'],
      segments: (json['segments'] as List)
          .map((s) => SegmentState.fromJson(s))
          .toList(),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}

class SegmentState {
  final int start;
  final int end;
  int downloadedBytes;
  String status; // pending, downloading, completed, failed

  SegmentState({
    required this.start,
    required this.end,
    this.downloadedBytes = 0,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'downloadedBytes': downloadedBytes,
      'status': status,
    };
  }

  factory SegmentState.fromJson(Map<String, dynamic> json) {
    return SegmentState(
      start: json['start'],
      end: json['end'],
      downloadedBytes: json['downloadedBytes'],
      status: json['status'],
    );
  }
}
