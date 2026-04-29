import 'package:flutter/material.dart';
import '../models/download_item.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class DownloadHistoryScreen extends StatefulWidget {
  final Future<void> Function(String url)? onRedownload;

  const DownloadHistoryScreen({super.key, this.onRedownload});

  @override
  State<DownloadHistoryScreen> createState() => _DownloadHistoryScreenState();
}

class _DownloadHistoryScreenState extends State<DownloadHistoryScreen> {
  final _databaseService = DatabaseService();
  final _searchController = TextEditingController();
  List<DownloadItem> _history = [];
  String _filter = 'all';
  String _query = '';

  /// Whether to show every user's downloads. Defaults to off; admins
  /// can flip it on to audit.
  bool _showAllUsers = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final auth = AuthService.instance;
    final scope = (_showAllUsers && auth.isAdmin) ? null : auth.currentUser?.id;
    final historyMaps =
        await _databaseService.getDownloadHistory(ownerUserId: scope);
    final history = historyMaps.map((map) => DownloadItem.fromMap(map)).toList();
    setState(() {
      _history = history;
    });
  }

  List<DownloadItem> get _filteredHistory {
    Iterable<DownloadItem> rows = _history;
    switch (_filter) {
      case 'completed':
        rows = rows.where((d) => d.status == 'completed');
        break;
      case 'failed':
        rows = rows.where((d) => d.status == 'failed');
        break;
      case 'cancelled':
        rows = rows.where((d) => d.status == 'cancelled');
        break;
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows.where((d) {
        return d.filename.toLowerCase().contains(q) ||
            d.url.toLowerCase().contains(q);
      });
    }
    return rows.toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthService.instance.isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download History'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: _showAllUsers ? 'Show only mine' : 'Show all users',
              icon: Icon(_showAllUsers ? Icons.group : Icons.person),
              onPressed: () {
                setState(() => _showAllUsers = !_showAllUsers);
                _loadHistory();
              },
            ),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search filename or URL',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _filteredHistory.isEmpty
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
                        onRedownload: () async {
                          final onRedownload = widget.onRedownload;
                          if (onRedownload == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Re-download is not available here'),
                              ),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Re-queuing ${item.filename}…'),
                            ),
                          );
                          await onRedownload(item.url);
                        },
                      );
                    },
                  ),
          ),
        ],
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

  String _formatDate(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
            Text(item.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 2),
            Text(
              '${item.status} • ${_formatDate(item.createdAt)}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'redownload') onRedownload();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'redownload', child: Text('Download again')),
            PopupMenuItem(value: 'delete', child: Text('Remove from history')),
          ],
        ),
      ),
    );
  }
}
