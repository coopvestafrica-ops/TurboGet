import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BatchImportScreen extends StatefulWidget {
  final Function(List<String>) onImport;
  
  const BatchImportScreen({super.key, required this.onImport});

  @override
  State<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends State<BatchImportScreen> {
  final _controller = TextEditingController();
  List<String> _urls = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parseUrls() {
    final text = _controller.text;
    // Split by newlines, commas, or spaces
    final urls = text
        .split(RegExp(r'[\n,\s]+'))
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty && _isValidUrl(url))
        .toList();
    
    setState(() {
      _urls = urls;
    });
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _controller.text = data!.text!;
      });
      _parseUrls();
    }
  }

  void _removeUrl(int index) {
    setState(() {
      _urls.removeAt(index);
    });
  }

  void _startDownloads() {
    if (_urls.isNotEmpty) {
      widget.onImport(_urls);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Import'),
        actions: [
          TextButton.icon(
            onPressed: _urls.isEmpty ? null : _startDownloads,
            icon: const Icon(Icons.download),
            label: Text('Download All (${_urls.length})'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'How to use',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter or paste multiple URLs, separated by newlines, commas, or spaces. Each URL will be added to the download queue.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Text input
            Expanded(
              flex: 2,
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Enter URLs here...\n\nExample:\nhttps://example.com/file1.mp4\nhttps://example.com/file2.mp3',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: _pasteFromClipboard,
                    tooltip: 'Paste from clipboard',
                  ),
                ),
                onChanged: (_) => _parseUrls(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _urls.isEmpty ? null : _startDownloads,
                    icon: const Icon(Icons.download),
                    label: Text('Add ${_urls.length} to Queue'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Preview list
            if (_urls.isNotEmpty) ...[
              Text(
                'Preview (${_urls.length} URLs)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 3,
                child: Card(
                  child: ListView.separated(
                    itemCount: _urls.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final url = _urls[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          _getUrlIcon(url),
                          color: _isValidUrl(url) ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          url.split('/').last.isEmpty ? url : url.split('/').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeUrl(index),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getUrlIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube') || lower.contains('youtu.be')) {
      return Icons.play_circle;
    }
    if (lower.contains('.mp4') || lower.contains('.mkv') || lower.contains('.avi')) {
      return Icons.video_file;
    }
    if (lower.contains('.mp3') || lower.contains('.wav') || lower.contains('.aac')) {
      return Icons.audio_file;
    }
    if (lower.contains('.jpg') || lower.contains('.png') || lower.contains('.gif')) {
      return Icons.image;
    }
    if (lower.contains('.zip') || lower.contains('.rar') || lower.contains('.7z')) {
      return Icons.archive;
    }
    return Icons.insert_drive_file;
  }
}
