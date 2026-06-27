# Supported File Types

TurboGet supports downloading **all file types** from any URL. This document lists the pre-configured media type recognition for common file formats.

## Overview

TurboGet uses **URL-based file type detection** - it detects file types by analyzing the URL/file extension. This means it can download any file type, but will provide enhanced metadata and icons for supported formats.

---

## Video Files 🎬

| Extension | MIME Type | Playable | Notes |
|-----------|-----------|----------|-------|
| `.mp4` | `video/mp4` | ✅ | Most common format, best compatibility |
| `.mkv` | `video/x-matroska` | ✅ | High quality, supports multiple audio tracks |
| `.avi` | `video/x-msvideo` | ✅ | Legacy format |
| `.mov` | `video/quicktime` | ✅ | Apple QuickTime format |
| `.wmv` | `video/x-ms-wmv` | ✅ | Windows Media format |
| `.flv` | `video/x-flv` | ✅ | Flash video (legacy) |
| `.webm` | `video/webm` | ✅ | Open web format |
| `.m4v` | `video/x-m4v` | ✅ | iTunes video format |
| `.3gp` | `video/3gpp` | ✅ | Mobile video format |
| `.mpeg` | `video/mpeg` | ✅ | Standard MPEG format |
| `.mpg` | `video/mpeg` | ✅ | Standard MPEG format |
| `.ts` | `video/MP2T` | ✅ | Transport stream format |
| `.vob` | `video/x-mpeg` | ✅ | DVD video format |

---

## Audio Files 🎵

| Extension | MIME Type | Playable | Notes |
|-----------|-----------|----------|-------|
| `.mp3` | `audio/mpeg` | ✅ | Most popular audio format |
| `.wav` | `audio/wav` | ✅ | Uncompressed audio |
| `.aac` | `audio/aac` | ✅ | Advanced Audio Coding |
| `.flac` | `audio/flac` | ✅ | Free Lossless Audio |
| `.ogg` | `audio/ogg` | ✅ | Ogg Vorbis format |
| `.m4a` | `audio/mp4` | ✅ | iTunes audio |
| `.wma` | `audio/x-ms-wma` | ✅ | Windows Media audio |
| `.aiff` | `audio/aiff` | ✅ | Audio Interchange File Format |
| `.opus` | `audio/opus` | ✅ | Opus codec |
| `.amr` | `audio/amr` | ✅ | Adaptive Multi-Rate |
| `.ape` | `audio/x-ape` | ✅ | Monkey's Audio |
| `.alac` | `audio/x-alac` | ✅ | Apple Lossless |

---

## Image Files 🖼️

| Extension | MIME Type | Viewable | Notes |
|-----------|-----------|----------|-------|
| `.jpg` | `image/jpeg` | ✅ | JPEG photos |
| `.jpeg` | `image/jpeg` | ✅ | JPEG photos |
| `.png` | `image/png` | ✅ | PNG images |
| `.gif` | `image/gif` | ✅ | Animated images |
| `.webp` | `image/webp` | ✅ | Modern web format |
| `.bmp` | `image/bmp` | ✅ | Bitmap |
| `.svg` | `image/svg+xml` | ✅ | Scalable Vector Graphics |
| `.ico` | `image/x-icon` | ✅ | Icon format |
| `.tiff` | `image/tiff` | ✅ | TIFF images |
| `.tif` | `image/tiff` | ✅ | TIFF images |
| `.heic` | `image/heic` | ✅ | High Efficiency Image |
| `.heif` | `image/heif` | ✅ | High Efficiency Image |
| `.raw` | `image/raw` | ✅ | Raw camera formats |
| `.cr2` | `image/x-canon-cr2` | ✅ | Canon RAW |
| `.nef` | `image/x-nikon-nef` | ✅ | Nikon RAW |

---

## Document Files 📄

| Extension | MIME Type | Notes |
|-----------|-----------|-------|
| `.pdf` | `application/pdf` | Adobe PDF |
| `.doc` | `application/msword` | Word 97-2003 |
| `.docx` | `application/vnd.openxmlformats-officedocument.wordprocessingml.document` | Word 2007+ |
| `.xls` | `application/vnd.ms-excel` | Excel 97-2003 |
| `.xlsx` | `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` | Excel 2007+ |
| `.ppt` | `application/vnd.ms-powerpoint` | PowerPoint 97-2003 |
| `.pptx` | `application/vnd.openxmlformats-officedocument.presentationml.presentation` | PowerPoint 2007+ |
| `.txt` | `text/plain` | Plain text |
| `.rtf` | `application/rtf` | Rich Text Format |
| `.odt` | `application/vnd.oasis.opendocument.text` | OpenDocument Text |
| `.ods` | `application/vnd.oasis.opendocument.spreadsheet` | OpenDocument Spreadsheet |
| `.odp` | `application/vnd.oasis.opendocument.presentation` | OpenDocument Presentation |
| `.csv` | `text/csv` | Comma-separated values |
| `.json` | `application/json` | JavaScript Object Notation |
| `.xml` | `application/xml` | Extensible Markup Language |
| `.html` | `text/html` | HTML document |
| `.htm` | `text/html` | HTML document |
| `.epub` | `application/epub+zip` | E-book format |
| `.md` | `text/markdown` | Markdown document |

---

## Archive Files 📦

| Extension | MIME Type | Notes |
|-----------|-----------|-------|
| `.zip` | `application/zip` | ZIP archive |
| `.rar` | `application/vnd.rar` | RAR archive |
| `.7z` | `application/x-7z-compressed` | 7-Zip archive |
| `.tar` | `application/x-tar` | Tape archive |
| `.gz` | `application/gzip` | Gzip compressed |
| `.bz2` | `application/x-bzip2` | Bzip2 compressed |
| `.xz` | `application/x-xz` | XZ compressed |
| `.tgz` | `application/gzip` | Tar + Gzip |
| `.iso` | `application/x-iso9660-image` | Disc image |
| `.dmg` | `application/x-apple-diskimage` | macOS disk image |

---

## Application Files 📱

| Extension | MIME Type | Notes |
|-----------|-----------|-------|
| `.apk` | `application/vnd.android.package-archive` | Android app |
| `.ipa` | `application/x-itunes-ipa` | iOS app |
| `.exe` | `application/x-msdownload` | Windows executable |
| `.msi` | `application/x-msi` | Windows installer |
| `.deb` | `application/x-debian-package` | Debian package |
| `.rpm` | `application/x-rpm` | RPM package |
| `.dmg` | `application/x-apple-diskimage` | macOS app |
| `.ttf` | `font/ttf` | TrueType font |
| `.otf` | `font/otf` | OpenType font |
| `.woff` | `font/woff` | Web Open Font |
| `.woff2` | `font/woff2` | Web Open Font 2 |
| `.eot` | `application/vnd.ms-fontobject` | Embedded OpenType |

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Video Formats | 13 |
| Audio Formats | 12 |
| Image Formats | 15 |
| Document Formats | 18 |
| Archive Formats | 10 |
| Application Formats | 12 |
| **Total Supported** | **80+** |

---

## How Detection Works

TurboGet uses a multi-step detection process:

1. **Extension Matching**: Checks the file extension against the known types
2. **MIME Type Lookup**: Falls back to MIME type detection
3. **Default Handling**: Unknown types are treated as generic downloads

### Example URLs

```dart
// Video detection
'https://example.com/video.mp4' → Video (MP4)
// ✓ Recognized as video

// Audio detection  
'https://example.com/song.flac' → Audio (FLAC)
// ✓ Recognized as audio

// Image detection
'https://example.com/photo.heic' → Image (HEIC)
// ✓ Recognized as image

// Unknown type
'https://example.com/file.xyz123' → Generic Download
// ✓ Recognized but with generic icon
```

---

## Adding Custom Types

To add support for additional file types, modify `lib/services/media_type_service.dart`:

```dart
// Add to the appropriate map
static const Map<String, MediaType> _customTypes = {
  '.xyz': MediaType(
    category: MediaType.application,
    extension: 'xyz',
    mimeType: 'application/xyz',
    icon: '📦',
  ),
};
```

---

## File Size Limits

There are **no hard file size limits** in TurboGet. However:

- **Practical Limits**: Device storage availability
- **Network Limits**: Connection stability for large files
- **Resume Support**: Downloads can be paused and resumed

### Resume Capability

TurboGet supports **partial downloads** for servers that support HTTP range requests, allowing:
- Pause and resume without data loss
- Automatic retry on connection failure
- Multi-segment parallel downloads for faster speeds

---

## Special Features

### Smart Filename Extraction

TurboGet intelligently extracts filenames from URLs:
- Removes query parameters (`?token=xxx`)
- Handles URL-encoded characters
- Sanitizes invalid characters
- Preserves proper file extensions

### Content-Type Detection

The app can optionally detect file types from server `Content-Type` headers, ensuring accurate type recognition even when URLs don't have proper extensions.

---

## Notes for Developers

- All supported types are defined in `MediaTypeService`
- New types can be added without code changes via configuration
- File type icons are emoji-based for cross-platform consistency
- MIME type mapping uses the `mime` package as fallback
