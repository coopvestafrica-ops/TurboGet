import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  Directory? _downloadDir;
  List<FileSystemEntity> _files = [];
  String? _currentPath;
  final List<String> _pathHistory = [];
  Map<String, String> _fileSizes = {};

  @override
  void initState() {
    super.initState();
    _initDirectory();
  }

  Future<void> _initDirectory() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        // Navigate to Downloads folder
        final downloadDir = Directory('${dir.path}/Download');
        if (await downloadDir.exists()) {
          _currentPath = downloadDir.path;
        } else {
          _currentPath = dir.path;
        }
        await _loadFiles();
      }
    } catch (e) {
      // Fallback to app documents directory
      final dir = await getApplicationDocumentsDirectory();
      _currentPath = dir.path;
      await _loadFiles();
    }
  }

  Future<void> _loadFiles() async {
    if (_currentPath == null) return;
    
    final dir = Directory(_currentPath!);
    if (!await dir.exists()) return;

    final files = await dir.list().toList();
    // Sort: directories first, then by name
    files.sort((a, b) {
      if (a is Directory && b is! Directory) return -1;
      if (a is! Directory && b is Directory) return 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });

    // Pre-compute file sizes
    final fileSizes = <String, String>{};
    for (final file in files) {
      if (file is File) {
        try {
          final stat = await file.stat();
          fileSizes[file.path] = _formatSizeSync(stat.size);
        } catch (e) {
          fileSizes[file.path] = 'Unknown';
        }
      }
    }

    setState(() {
      _files = files;
      _fileSizes = fileSizes;
    });
  }

  String _formatSizeSync(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _navigateToFolder(String path) {
    _pathHistory.add(_currentPath!);
    setState(() {
      _currentPath = path;
    });
    _loadFiles();
  }

  void _navigateBack() {
    if (_pathHistory.isNotEmpty) {
      setState(() {
        _currentPath = _pathHistory.removeLast();
      });
      _loadFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Browser'),
        leading: _pathHistory.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _navigateBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          // Current path display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _currentPath ?? 'Loading...',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          // File list
          Expanded(
            child: _files.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Empty folder'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      final isDirectory = file is Directory;
                      final name = file.path.split('/').last;

                      return ListTile(
                        leading: Icon(
                          isDirectory ? Icons.folder : _getFileIcon(name),
                          color: isDirectory ? Colors.amber : _getFileColor(name),
                        ),
                        title: Text(name),
                        subtitle: isDirectory ? null : Text(_fileSizes[file.path] ?? 'Loading...'),
                        trailing: isDirectory
                            ? const Icon(Icons.chevron_right)
                            : PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'open',
                                    child: ListTile(
                                      leading: Icon(Icons.open_in_new),
                                      title: Text('Open'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'share',
                                    child: ListTile(
                                      leading: Icon(Icons.share),
                                      title: Text('Share'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete, color: Colors.red),
                                      title: Text('Delete', style: TextStyle(color: Colors.red)),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                                onSelected: (value) => _handleFileAction(value, file),
                              ),
                        onTap: isDirectory ? () => _navigateToFolder(file.path) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFileAction(String action, FileSystemEntity file) async {
    switch (action) {
      case 'open':
        final uri = Uri.file(file.path);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
        break;
      case 'share':
        await Share.shareXFiles([XFile(file.path)]);
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete File'),
            content: Text('Are you sure you want to delete "${file.path.split('/').last}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            if (file is File) {
              await file.delete();
            } else if (file is Directory) {
              await file.delete(recursive: true);
            }
            _loadFiles();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File deleted')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete: $e')),
              );
            }
          }
        }
        break;
    }
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'flac':
        return Icons.audio_file;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'apk':
        return Icons.android;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return Colors.purple;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'flac':
        return Colors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Colors.green;
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.brown;
      case 'apk':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Future<String> _formatFileSize(FileSystemEntity file) async {
    try {
      final stat = await file.stat();
      final size = stat.size;
      if (size < 1024) return '$size B';
      if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
      if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } catch (e) {
      return 'Unknown';
    }
  }
}
