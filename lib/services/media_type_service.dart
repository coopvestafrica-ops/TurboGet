import 'dart:io';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

/// Represents a supported media type with metadata
class MediaType {
  final String category;
  final String extension;
  final String mimeType;
  final bool isPlayable;
  final bool isViewable;
  final bool isDownloadable;
  final String icon;

  const MediaType({
    required this.category,
    required this.extension,
    required this.mimeType,
    this.isPlayable = false,
    this.isViewable = true,
    this.isDownloadable = true,
    required this.icon,
  });

  static const video = 'video';
  static const audio = 'audio';
  static const image = 'image';
  static const document = 'document';
  static const archive = 'archive';
  static const application = 'application';
  static const other = 'other';
}

/// Service for detecting and categorizing media types
class MediaTypeService {
  static final MediaTypeService _instance = MediaTypeService._internal();
  factory MediaTypeService() => _instance;
  MediaTypeService._internal();

  /// Video file extensions and their metadata
  static const Map<String, MediaType> _videoTypes = {
    '.mp4': MediaType(category: MediaType.video, extension: 'mp4', mimeType: 'video/mp4', isPlayable: true, icon: '🎬'),
    '.mkv': MediaType(category: MediaType.video, extension: 'mkv', mimeType: 'video/x-matroska', isPlayable: true, icon: '🎬'),
    '.avi': MediaType(category: MediaType.video, extension: 'avi', mimeType: 'video/x-msvideo', isPlayable: true, icon: '🎬'),
    '.mov': MediaType(category: MediaType.video, extension: 'mov', mimeType: 'video/quicktime', isPlayable: true, icon: '🎬'),
    '.wmv': MediaType(category: MediaType.video, extension: 'wmv', mimeType: 'video/x-ms-wmv', isPlayable: true, icon: '🎬'),
    '.flv': MediaType(category: MediaType.video, extension: 'flv', mimeType: 'video/x-flv', isPlayable: true, icon: '🎬'),
    '.webm': MediaType(category: MediaType.video, extension: 'webm', mimeType: 'video/webm', isPlayable: true, icon: '🎬'),
    '.m4v': MediaType(category: MediaType.video, extension: 'm4v', mimeType: 'video/x-m4v', isPlayable: true, icon: '🎬'),
    '.3gp': MediaType(category: MediaType.video, extension: '3gp', mimeType: 'video/3gpp', isPlayable: true, icon: '🎬'),
    '.mpeg': MediaType(category: MediaType.video, extension: 'mpeg', mimeType: 'video/mpeg', isPlayable: true, icon: '🎬'),
    '.mpg': MediaType(category: MediaType.video, extension: 'mpg', mimeType: 'video/mpeg', isPlayable: true, icon: '🎬'),
    '.ts': MediaType(category: MediaType.video, extension: 'ts', mimeType: 'video/MP2T', isPlayable: true, icon: '🎬'),
    '.vob': MediaType(category: MediaType.video, extension: 'vob', mimeType: 'video/x-mpeg', isPlayable: true, icon: '🎬'),
  };

  /// Audio file extensions and their metadata
  static const Map<String, MediaType> _audioTypes = {
    '.mp3': MediaType(category: MediaType.audio, extension: 'mp3', mimeType: 'audio/mpeg', isPlayable: true, icon: '🎵'),
    '.wav': MediaType(category: MediaType.audio, extension: 'wav', mimeType: 'audio/wav', isPlayable: true, icon: '🎵'),
    '.aac': MediaType(category: MediaType.audio, extension: 'aac', mimeType: 'audio/aac', isPlayable: true, icon: '🎵'),
    '.flac': MediaType(category: MediaType.audio, extension: 'flac', mimeType: 'audio/flac', isPlayable: true, icon: '🎵'),
    '.ogg': MediaType(category: MediaType.audio, extension: 'ogg', mimeType: 'audio/ogg', isPlayable: true, icon: '🎵'),
    '.m4a': MediaType(category: MediaType.audio, extension: 'm4a', mimeType: 'audio/mp4', isPlayable: true, icon: '🎵'),
    '.wma': MediaType(category: MediaType.audio, extension: 'wma', mimeType: 'audio/x-ms-wma', isPlayable: true, icon: '🎵'),
    '.aiff': MediaType(category: MediaType.audio, extension: 'aiff', mimeType: 'audio/aiff', isPlayable: true, icon: '🎵'),
    '.opus': MediaType(category: MediaType.audio, extension: 'opus', mimeType: 'audio/opus', isPlayable: true, icon: '🎵'),
    '.amr': MediaType(category: MediaType.audio, extension: 'amr', mimeType: 'audio/amr', isPlayable: true, icon: '🎵'),
    '.ape': MediaType(category: MediaType.audio, extension: 'ape', mimeType: 'audio/x-ape', isPlayable: true, icon: '🎵'),
    '.alac': MediaType(category: MediaType.audio, extension: 'alac', mimeType: 'audio/x-alac', isPlayable: true, icon: '🎵'),
  };

  /// Image file extensions and their metadata
  static const Map<String, MediaType> _imageTypes = {
    '.jpg': MediaType(category: MediaType.image, extension: 'jpg', mimeType: 'image/jpeg', isViewable: true, icon: '🖼️'),
    '.jpeg': MediaType(category: MediaType.image, extension: 'jpeg', mimeType: 'image/jpeg', isViewable: true, icon: '🖼️'),
    '.png': MediaType(category: MediaType.image, extension: 'png', mimeType: 'image/png', isViewable: true, icon: '🖼️'),
    '.gif': MediaType(category: MediaType.image, extension: 'gif', mimeType: 'image/gif', isViewable: true, icon: '🖼️'),
    '.webp': MediaType(category: MediaType.image, extension: 'webp', mimeType: 'image/webp', isViewable: true, icon: '🖼️'),
    '.bmp': MediaType(category: MediaType.image, extension: 'bmp', mimeType: 'image/bmp', isViewable: true, icon: '🖼️'),
    '.svg': MediaType(category: MediaType.image, extension: 'svg', mimeType: 'image/svg+xml', isViewable: true, icon: '🖼️'),
    '.ico': MediaType(category: MediaType.image, extension: 'ico', mimeType: 'image/x-icon', isViewable: true, icon: '🖼️'),
    '.tiff': MediaType(category: MediaType.image, extension: 'tiff', mimeType: 'image/tiff', isViewable: true, icon: '🖼️'),
    '.tif': MediaType(category: MediaType.image, extension: 'tif', mimeType: 'image/tiff', isViewable: true, icon: '🖼️'),
    '.heic': MediaType(category: MediaType.image, extension: 'heic', mimeType: 'image/heic', isViewable: true, icon: '🖼️'),
    '.heif': MediaType(category: MediaType.image, extension: 'heif', mimeType: 'image/heif', isViewable: true, icon: '🖼️'),
    '.raw': MediaType(category: MediaType.image, extension: 'raw', mimeType: 'image/raw', isViewable: true, icon: '🖼️'),
    '.cr2': MediaType(category: MediaType.image, extension: 'cr2', mimeType: 'image/x-canon-cr2', isViewable: true, icon: '🖼️'),
    '.nef': MediaType(category: MediaType.image, extension: 'nef', mimeType: 'image/x-nikon-nef', isViewable: true, icon: '🖼️'),
  };

  /// Document file extensions
  static const Map<String, MediaType> _documentTypes = {
    '.pdf': MediaType(category: MediaType.document, extension: 'pdf', mimeType: 'application/pdf', icon: '📄'),
    '.doc': MediaType(category: MediaType.document, extension: 'doc', mimeType: 'application/msword', icon: '📄'),
    '.docx': MediaType(category: MediaType.document, extension: 'docx', mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', icon: '📄'),
    '.xls': MediaType(category: MediaType.document, extension: 'xls', mimeType: 'application/vnd.ms-excel', icon: '📊'),
    '.xlsx': MediaType(category: MediaType.document, extension: 'xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', icon: '📊'),
    '.ppt': MediaType(category: MediaType.document, extension: 'ppt', mimeType: 'application/vnd.ms-powerpoint', icon: '📽️'),
    '.pptx': MediaType(category: MediaType.document, extension: 'pptx', mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation', icon: '📽️'),
    '.txt': MediaType(category: MediaType.document, extension: 'txt', mimeType: 'text/plain', icon: '📝'),
    '.rtf': MediaType(category: MediaType.document, extension: 'rtf', mimeType: 'application/rtf', icon: '📝'),
    '.odt': MediaType(category: MediaType.document, extension: 'odt', mimeType: 'application/vnd.oasis.opendocument.text', icon: '📄'),
    '.ods': MediaType(category: MediaType.document, extension: 'ods', mimeType: 'application/vnd.oasis.opendocument.spreadsheet', icon: '📊'),
    '.odp': MediaType(category: MediaType.document, extension: 'odp', mimeType: 'application/vnd.oasis.opendocument.presentation', icon: '📽️'),
    '.csv': MediaType(category: MediaType.document, extension: 'csv', mimeType: 'text/csv', icon: '📊'),
    '.json': MediaType(category: MediaType.document, extension: 'json', mimeType: 'application/json', icon: '📋'),
    '.xml': MediaType(category: MediaType.document, extension: 'xml', mimeType: 'application/xml', icon: '📋'),
    '.html': MediaType(category: MediaType.document, extension: 'html', mimeType: 'text/html', icon: '🌐'),
    '.htm': MediaType(category: MediaType.document, extension: 'htm', mimeType: 'text/html', icon: '🌐'),
    '.epub': MediaType(category: MediaType.document, extension: 'epub', mimeType: 'application/epub+zip', icon: '📖'),
    '.md': MediaType(category: MediaType.document, extension: 'md', mimeType: 'text/markdown', icon: '📝'),
  };

  /// Archive file extensions
  static const Map<String, MediaType> _archiveTypes = {
    '.zip': MediaType(category: MediaType.archive, extension: 'zip', mimeType: 'application/zip', icon: '📦'),
    '.rar': MediaType(category: MediaType.archive, extension: 'rar', mimeType: 'application/vnd.rar', icon: '📦'),
    '.7z': MediaType(category: MediaType.archive, extension: '7z', mimeType: 'application/x-7z-compressed', icon: '📦'),
    '.tar': MediaType(category: MediaType.archive, extension: 'tar', mimeType: 'application/x-tar', icon: '📦'),
    '.gz': MediaType(category: MediaType.archive, extension: 'gz', mimeType: 'application/gzip', icon: '📦'),
    '.bz2': MediaType(category: MediaType.archive, extension: 'bz2', mimeType: 'application/x-bzip2', icon: '📦'),
    '.xz': MediaType(category: MediaType.archive, extension: 'xz', mimeType: 'application/x-xz', icon: '📦'),
    '.tgz': MediaType(category: MediaType.archive, extension: 'tgz', mimeType: 'application/gzip', icon: '📦'),
    '.iso': MediaType(category: MediaType.archive, extension: 'iso', mimeType: 'application/x-iso9660-image', icon: '💿'),
    '.dmg': MediaType(category: MediaType.archive, extension: 'dmg', mimeType: 'application/x-apple-diskimage', icon: '💿'),
  };

  /// Application file extensions
  static const Map<String, MediaType> _applicationTypes = {
    '.apk': MediaType(category: MediaType.application, extension: 'apk', mimeType: 'application/vnd.android.package-archive', isDownloadable: true, icon: '📱'),
    '.ipa': MediaType(category: MediaType.application, extension: 'ipa', mimeType: 'application/x-itunes-ipa', isDownloadable: true, icon: '📱'),
    '.exe': MediaType(category: MediaType.application, extension: 'exe', mimeType: 'application/x-executable', icon: '💻'),
    '.msi': MediaType(category: MediaType.application, extension: 'msi', mimeType: 'application/x-msi', icon: '💻'),
    '.deb': MediaType(category: MediaType.application, extension: 'deb', mimeType: 'application/x-debian-package', icon: '🐧'),
    '.rpm': MediaType(category: MediaType.application, extension: 'rpm', mimeType: 'application/x-rpm', icon: '🐧'),
    '.dmg': MediaType(category: MediaType.application, extension: 'dmg', mimeType: 'application/x-apple-diskimage', icon: '🍎'),
    '.ttf': MediaType(category: MediaType.application, extension: 'ttf', mimeType: 'font/ttf', icon: '🔤'),
    '.otf': MediaType(category: MediaType.application, extension: 'otf', mimeType: 'font/otf', icon: '🔤'),
    '.woff': MediaType(category: MediaType.application, extension: 'woff', mimeType: 'font/woff', icon: '🔤'),
    '.woff2': MediaType(category: MediaType.application, extension: 'woff2', mimeType: 'font/woff2', icon: '🔤'),
    '.eot': MediaType(category: MediaType.application, extension: 'eot', mimeType: 'application/vnd.ms-fontobject', icon: '🔤'),
  };

  /// All supported media types combined
  static final Map<String, MediaType> _allMediaTypes = {
    ..._videoTypes,
    ..._audioTypes,
    ..._imageTypes,
    ..._documentTypes,
    ..._archiveTypes,
    ..._applicationTypes,
  };

  /// Get media type from file extension
  MediaType? getMediaType(String filename) {
    final ext = path.extension(filename).toLowerCase();
    return _allMediaTypes[ext];
  }

  /// Get media type from MIME type
  MediaType? getMediaTypeFromMime(String mimeType) {
    for (final entry in _allMediaTypes.entries) {
      if (entry.value.mimeType == mimeType) {
        return entry.value;
      }
    }
    return null;
  }

  /// Check if a file is a video
  bool isVideo(String filename) {
    final ext = path.extension(filename).toLowerCase();
    return _videoTypes.containsKey(ext);
  }

  /// Check if a file is audio
  bool isAudio(String filename) {
    final ext = path.extension(filename).toLowerCase();
    return _audioTypes.containsKey(ext);
  }

  /// Check if a file is an image
  bool isImage(String filename) {
    final ext = path.extension(filename).toLowerCase();
    return _imageTypes.containsKey(ext);
  }

  /// Check if a file is a document
  bool isDocument(String filename) {
    final ext = path.extension(filename).toLowerCase();
    return _documentTypes.containsKey(ext);
  }

  /// Check if a file is an archive
  bool isArchive(String filename) {
    final ext = path.extension(filename).toLowerCase();
    return _archiveTypes.containsKey(ext);
  }

  /// Check if a file is an application
  bool isApplication(String filename) {
    final ext = path.extension(filename).toLowerCase();
    return _applicationTypes.containsKey(ext);
  }

  /// Check if a file is playable (video or audio)
  bool isPlayable(String filename) {
    final mediaType = getMediaType(filename);
    return mediaType?.isPlayable ?? false;
  }

  /// Check if a file is viewable (image)
  bool isViewable(String filename) {
    final mediaType = getMediaType(filename);
    return mediaType?.isViewable ?? false;
  }

  /// Get MIME type from filename
  String? getMimeType(String filename) {
    // First try our known types
    final ext = path.extension(filename).toLowerCase();
    final knownType = _allMediaTypes[ext];
    if (knownType != null) {
      return knownType.mimeType;
    }
    
    // Fall back to mime package
    return lookupMimeType(filename);
  }

  /// Get file category
  String getCategory(String filename) {
    final mediaType = getMediaType(filename);
    return mediaType?.category ?? MediaType.other;
  }

  /// Get icon for file type
  String getIcon(String filename) {
    final mediaType = getMediaType(filename);
    return mediaType?.icon ?? '📁';
  }

  /// Get all supported video extensions
  List<String> get videoExtensions => _videoTypes.keys.toList();

  /// Get all supported audio extensions
  List<String> get audioExtensions => _audioTypes.keys.toList();

  /// Get all supported image extensions
  List<String> get imageExtensions => _imageTypes.keys.toList();

  /// Get all supported document extensions
  List<String> get documentExtensions => _documentTypes.keys.toList();

  /// Get all supported archive extensions
  List<String> get archiveExtensions => _archiveTypes.keys.toList();

  /// Get all supported application extensions
  List<String> get applicationExtensions => _applicationTypes.keys.toList();

  /// Get all supported extensions
  List<String> get allSupportedExtensions => _allMediaTypes.keys.toList();

  /// Check if extension is supported
  bool isSupported(String filename) {
    final ext = path.extension(filename).toLowerCase();
    return _allMediaTypes.containsKey(ext);
  }

  /// Get count of supported types by category
  Map<String, int> getCategoryStats() {
    return {
      'video': _videoTypes.length,
      'audio': _audioTypes.length,
      'image': _imageTypes.length,
      'document': _documentTypes.length,
      'archive': _archiveTypes.length,
      'application': _applicationTypes.length,
      'total': _allMediaTypes.length,
    };
  }
}

/// Global media type service instance
final mediaTypeService = MediaTypeService();
