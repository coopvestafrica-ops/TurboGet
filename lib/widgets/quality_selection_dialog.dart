import 'package:flutter/material.dart';
import '../services/platform_analyzer.dart';

class QualitySelectionDialog extends StatelessWidget {
  final List<PlatformVideoQuality> qualities;
  final String title;
  final String? thumbnail;

  const QualitySelectionDialog({
    super.key,
    required this.qualities,
    required this.title,
    this.thumbnail,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbnail != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  thumbnail!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Select Quality',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: qualities.map((quality) {
                    String subtitle = '';
                    if (quality.width != null && quality.height != null) {
                      subtitle = '${quality.width}x${quality.height}';
                    }
                    if (quality.fileSize != null) {
                      subtitle += ' • ${_formatFileSize(quality.fileSize!)}';
                    }
                    if (quality.bitrate != null) {
                      subtitle += ' • ${_formatBitrate(quality.bitrate!)}';
                    }

                    return ListTile(
                      title: Text(quality.quality),
                      subtitle: Text(subtitle),
                      leading: Icon(_getIconForQuality(quality)),
                      onTap: () => Navigator.of(context).pop(quality),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForQuality(PlatformVideoQuality quality) {
    if (quality.quality.toLowerCase().contains('audio')) {
      return Icons.audiotrack;
    }
    if (quality.quality.toLowerCase().contains('video')) {
      return Icons.high_quality;
    }
    return Icons.file_download;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatBitrate(int bitsPerSecond) {
    if (bitsPerSecond < 1024) return '$bitsPerSecond bps';
    if (bitsPerSecond < 1024 * 1024) return '${(bitsPerSecond / 1024).toStringAsFixed(1)} Kbps';
    return '${(bitsPerSecond / (1024 * 1024)).toStringAsFixed(1)} Mbps';
  }
}

Future<PlatformVideoQuality?> showQualitySelectionDialog(
  BuildContext context,
  List<PlatformVideoQuality> qualities,
  String title,
  String? thumbnail,
) {
  return showDialog<PlatformVideoQuality>(
    context: context,
    builder: (context) => QualitySelectionDialog(
      qualities: qualities,
      title: title,
      thumbnail: thumbnail,
    ),
  );
}
