import 'package:flutter/material.dart';
import '../models/download_item.dart';
import '../services/database_service.dart';

class DownloadHistoryScreen extends StatefulWidget {
  const DownloadHistoryScreen({super.key});

  @override
  State<DownloadHistoryScreen> createState() => _DownloadHistoryScreenState();
}

class _DownloadHistoryScreenState extends State<DownloadHistoryScreen> {
  final _databaseService = DatabaseService();
  List<DownloadItem> _history = [];
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _databaseService.getDownloadHistory();
    setState(() {
      _history = history;
    });
  }

  List<DownloadItem> get _filteredHistory {
    switch (_filter) {
      case 'completed':
        return _history.where((d) => d.status == 'completed').toList();
      case 'failed':
        return _history.where((d) => d.status == 'failed').toList();
      case 'cancelled':
        return _history.where((d) => d.status == 'cancelled').toList();
      default:
        return _history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download History'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'completed', child: Text('Completed')),
              const PopupMenuItem(value: 'failed', child: Text('Failed')),
              const PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
          ),
        ],
      ),
      body: _filteredHistory.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No download history'),
                  SizedBox(height: 8),
                  Text(
                    'Your completed downloads will appear here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _filteredHistory.length,
              itemBuilder: (context, index) {
                final item = _filteredHistory[index];
                return _HistoryTile(
                  item: item,
                  onDelete: () async {
                    await _databaseService.deleteDownloadHistory(item.id);
                    _loadHistory();
                  },
                  onRedownload: () {
                    // TODO: Trigger redownload
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Adding to download queue...')),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback onDelete;
  final VoidCallback onRedownload;

  const _HistoryTile({
    required this.item,
    required this.onDelete,
    required this.onRedownload,
  });

  IconData get _statusIcon {
    switch (item.status) {
      case 'completed':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.download;
    }
  }

  Color get _statusColor {
    switch (item.status) {
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'cancelled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor.withValues(alpha: 0.2),
          child: Icon(_statusIcon, color: _statusColor),
        ),
        title: Text(
          item.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatDate(item.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatSize(item.totalSize),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            if (item.status != 'completed')
              const PopupMenuItem(
                value: 'redownload',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Download Again'),
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
          onSelected: (value) {
            if (value == 'delete') {
              onDelete();
            } else if (value == 'redownload') {
              onRedownload();
            }
          },
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
