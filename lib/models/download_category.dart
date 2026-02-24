enum DownloadCategory {
  video,
  audio,
  document,
  image,
  archive,
  apk,
  other,
}

extension DownloadCategoryExtension on DownloadCategory {
  String get displayName {
    switch (this) {
      case DownloadCategory.video:
        return 'Video';
      case DownloadCategory.audio:
        return 'Audio';
      case DownloadCategory.document:
        return 'Document';
      case DownloadCategory.image:
        return 'Image';
      case DownloadCategory.archive:
        return 'Archive';
      case DownloadCategory.apk:
        return 'APK';
      case DownloadCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case DownloadCategory.video:
        return '🎬';
      case DownloadCategory.audio:
        return '🎵';
      case DownloadCategory.document:
        return '📄';
      case DownloadCategory.image:
        return '🖼️';
      case DownloadCategory.archive:
        return '📦';
      case DownloadCategory.apk:
        return '📱';
      case DownloadCategory.other:
        return '📁';
    }
  }

  static DownloadCategory fromFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    
    // Video
    if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v'].contains(ext)) {
      return DownloadCategory.video;
    }
    
    // Audio
    if (['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma'].contains(ext)) {
      return DownloadCategory.audio;
    }
    
    // Document
    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'odt'].contains(ext)) {
      return DownloadCategory.document;
    }
    
    // Image
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'ico'].contains(ext)) {
      return DownloadCategory.image;
    }
    
    // Archive
    if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2'].contains(ext)) {
      return DownloadCategory.archive;
    }
    
    // APK
    if (['apk', 'xapk'].contains(ext)) {
      return DownloadCategory.apk;
    }
    
    return DownloadCategory.other;
  }
}
