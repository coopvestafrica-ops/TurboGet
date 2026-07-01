import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/download_item.dart';
import '../services/turbo_downloader_engine.dart';
import '../services/media_type_service.dart';
import '../services/auth_service.dart';
import '../services/ad_manager.dart';
import '../services/logger_service.dart';
import '../services/database_service.dart';
import 'login_screen.dart';
import 'admin_panel.dart';
import 'settings_screen.dart';
import 'download_history_screen.dart';
import 'file_browser_screen.dart';
import 'batch_import_screen.dart';
import 'about_screen.dart';
import 'media_player_screen.dart';

/// Turbo Dashboard - The Ultimate Download Experience
class TurboDashboard extends ConsumerStatefulWidget {
  const TurboDashboard({super.key});

  @override
  ConsumerState<TurboDashboard> createState() => _TurboDashboardState();
}

class _TurboDashboardState extends ConsumerState<TurboDashboard>
    with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final MediaTypeService _mediaType = MediaTypeService();
  final DatabaseService _database = DatabaseService();

  List<TurboDownloadItem> _activeDownloads = [];
  List<TurboDownloadItem> _completedDownloads = [];
  List<TurboDownloadItem> _queue = [];
  Timer? _clipboardTimer;
  Timer? _refreshTimer;
  
  double _totalSpeed = 0;
  double _peakSpeed = 0;
  int _totalDownloaded = 0;
  int _completedCount = 0;
  bool _isInitialized = false;

  // Stats
  int _totalDownloads = 0;
  int _activeCount = 0;
  int _queueCount = 0;
  int _failedCount = 0;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize turbo downloader
      await turboDownloader.initialize();
      
      // Setup callbacks
      turboDownloader.onProgress = _onProgress;
      turboDownloader.onComplete = _onComplete;
      turboDownloader.onError = _onError;
      turboDownloader.onQueueChanged = _onQueueChanged;
      turboDownloader.onSpeedUpdate = _onSpeedUpdate;

      // Load data
      _loadData();
      
      // Start refresh timer
      _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _updateSpeeds();
      });

      // Start clipboard monitoring
      _startClipboardMonitoring();

      setState(() => _isInitialized = true);
    } catch (e) {
      logger.error('TurboDashboard', 'Initialization failed', error: e);
    }
  }

  void _onProgress(TurboDownloadItem item) {
    if (mounted) {
      setState(() {
        _totalSpeed = turboDownloader.getTotalSpeed();
        _peakSpeed = turboDownloader.getPeakSpeed();
      });
    }
  }

  void _onComplete(TurboDownloadItem item) {
    if (mounted) {
      setState(() {
        _loadData();
        _totalSpeed = turboDownloader.getTotalSpeed();
      });
      _showCompletedSnackbar(item);
    }
  }

  void _onError(TurboDownloadItem item, String error) {
    if (mounted) {
      setState(() => _loadData());
      _showErrorSnackbar(item, error);
    }
  }

  void _onQueueChanged(List<TurboDownloadItem> queue) {
    if (mounted) {
      setState(() => _queue = queue);
    }
  }

  void _onSpeedUpdate(double total, double average) {
    if (mounted) {
      setState(() {
        _totalSpeed = total;
        _peakSpeed = turboDownloader.getPeakSpeed();
      });
    }
  }

  void _updateSpeeds() {
    if (mounted) {
      setState(() {
        _totalSpeed = turboDownloader.getTotalSpeed();
        _peakSpeed = turboDownloader.getPeakSpeed();
      });
    }
  }

  void _loadData() {
    final all = turboDownloader.getAllDownloads();
    _activeDownloads = turboDownloader.getActiveDownloads();
    _completedDownloads = turboDownloader.getCompletedDownloads();
    _queue = turboDownloader.getQueue();
    
    _totalDownloads = all.length;
    _activeCount = _activeDownloads.length;
    _queueCount = _queue.length;
    _completedCount = _completedDownloads.length;
    _failedCount = turboDownloader.getFailedDownloads().length;
    
    _totalDownloaded = all.fold(0, (sum, d) => sum + d.downloadedSize);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _clipboardTimer?.cancel();
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startClipboardMonitoring() {
    _clipboardTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && _isValidUrl(data!.text!)) {
        if (_urlController.text.isEmpty) {
          _showClipboardSnackbar(data.text!);
        }
      }
    });
  }

  bool _isValidUrl(String text) {
    return Uri.tryParse(text)?.hasAbsolutePath == true &&
        (text.startsWith('http://') || text.startsWith('https://'));
  }

  void _showClipboardSnackbar(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.content_paste, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📋 URL detected in clipboard'),
                  Text(
                    url.length > 40 ? '${url.substring(0, 40)}...' : url,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: '📥 Paste',
          onPressed: () {
            _urlController.text = url;
            _urlFocusNode.requestFocus();
          },
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCompletedSnackbar(TurboDownloadItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade700,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✅ Download Complete!', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(item.filename, overflow: TextOverflow.ellipsis),
                  Text(_formatSize(item.totalSize), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => _openFile(item),
        ),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(TurboDownloadItem item, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('❌ ${item.filename}', overflow: TextOverflow.ellipsis),
                  Text(error, style: const TextStyle(fontSize: 12), maxLines: 2),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => turboDownloader.retryDownload(item.id),
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openFile(TurboDownloadItem item) {
    if (item.downloadPath != null && _mediaType.isPlayable(item.filename)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaPlayerScreen(filePath: item.downloadPath!),
        ),
      );
    }
  }

  Future<void> _startDownload(String url) async {
    if (!_isValidUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('❌ Please enter a valid URL'),
        ),
      );
      return;
    }

    try {
      await turboDownloader.download(url);
      _urlController.clear();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.blue,
            content: Text('🚀 Download started!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      logger.error('TurboDashboard', 'Download failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('❌ Download failed: $e'),
          ),
        );
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp'].contains(ext)) {
      return Icons.movie;
    }
    if (['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma'].contains(ext)) {
      return Icons.music_note;
    }
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext)) {
      return Icons.image;
    }
    if (['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext)) {
      return Icons.description;
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return Icons.folder_zip;
    }
    return Icons.insert_drive_file;
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(TurboDownloadStatus status) {
    switch (status) {
      case TurboDownloadStatus.downloading:
        return Colors.blue;
      case TurboDownloadStatus.completed:
        return Colors.green;
      case TurboDownloadStatus.paused:
        return Colors.orange;
      case TurboDownloadStatus.failed:
        return Colors.red;
      case TurboDownloadStatus.queued:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(TurboDownloadStatus status) {
    switch (status) {
      case TurboDownloadStatus.downloading:
        return Icons.downloading;
      case TurboDownloadStatus.completed:
        return Icons.check_circle;
      case TurboDownloadStatus.paused:
        return Icons.pause_circle;
      case TurboDownloadStatus.failed:
        return Icons.error;
      case TurboDownloadStatus.queued:
        return Icons.schedule;
      case TurboDownloadStatus.connecting:
        return Icons.sync;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            _buildAppBar(theme, isDark),

            // Speed Meter
            SliverToBoxAdapter(child: _buildSpeedMeter(isDark)),

            // Stats Cards
            SliverToBoxAdapter(child: _buildStatsSection(theme, isDark)),

            // Download Input
            SliverToBoxAdapter(child: _buildDownloadInput(theme, isDark)),

            // Active Downloads
            if (_activeDownloads.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader('🔥 Active Downloads', Icons.downloading, Colors.red),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildDownloadCard(_activeDownloads[index], theme, isDark),
                  childCount: _activeDownloads.length,
                ),
              ),
            ],

            // Queue
            if (_queue.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader('📋 Queue', Icons.queue, Colors.purple),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildQueueCard(_queue[index], theme, isDark),
                  childCount: _queue.length,
                ),
              ),
            ],

            // Completed Downloads
            if (_completedDownloads.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader('✅ Completed', Icons.check_circle, Colors.green),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildCompletedCard(_completedDownloads[index], theme, isDark),
                  childCount: math.min(_completedDownloads.length, 10),
                ),
              ),
              if (_completedDownloads.length > 10)
                SliverToBoxAdapter(
                  child: _buildShowMoreButton(),
                ),
            ],

            // Empty State
            if (_activeDownloads.isEmpty && _queue.isEmpty && _completedDownloads.isEmpty)
              SliverFillRemaining(child: _buildEmptyState(theme)),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(theme),
    );
  }

  Widget _buildAppBar(ThemeData theme, bool isDark) {
    return SliverAppBar(
      floating: true,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.purple],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bolt, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TurboGet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              Text(
                'Enterprise Download Manager',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => _loadData()),
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          tooltip: 'Settings',
        ),
      ],
    );
  }

  Widget _buildSpeedMeter(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade900,
            Colors.purple.shade900,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSpeedIndicator(
                '⚡ Current',
                _formatSpeed(_totalSpeed),
                _totalSpeed > 0 ? Colors.greenAccent : Colors.grey,
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white24,
              ),
              _buildSpeedIndicator(
                '🚀 Peak',
                _formatSpeed(_peakSpeed),
                Colors.amber,
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white24,
              ),
              _buildSpeedIndicator(
                '📊 Downloads',
                '$_activeCount active',
                Colors.blueAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar animation
          if (_totalSpeed > 0)
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: math.min(_totalSpeed / (10 * 1024 * 1024), 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.greenAccent, Colors.yellowAccent],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedIndicator(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard(Icons.download, _totalDownloads, 'Total', Colors.blue, theme, isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard(Icons.check_circle, _completedCount, 'Done', Colors.green, theme, isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard(Icons.queue, _queueCount, 'Queue', Colors.purple, theme, isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard(Icons.error, _failedCount, 'Failed', Colors.red, theme, isDark)),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, int value, String label, Color color, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadInput(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.link, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocusNode,
              decoration: const InputDecoration(
                hintText: 'Paste URL here...',
                border: InputBorder.none,
              ),
              onSubmitted: _startDownload,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.purple],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: () => _startDownload(_urlController.text),
              tooltip: 'Start Download',
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(TurboDownloadItem item, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getFileIcon(item.filename),
                color: _getStatusColor(item.status),
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.filename,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(_getStatusIcon(item.status), size: 12, color: _getStatusColor(item.status)),
                        const SizedBox(width: 4),
                        Text(
                          item.statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(item.status),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.connectionsUsed} connections',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Speed
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.formattedSpeed,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    item.estimatedTimeRemaining,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.progress / 100,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(_getStatusColor(item.status)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          // Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.progress}% • ${_formatSize(item.downloadedSize)} / ${_formatSize(item.totalSize)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Row(
                children: [
                  // Pause/Resume
                  IconButton(
                    icon: Icon(
                      item.status == TurboDownloadStatus.downloading
                          ? Icons.pause
                          : Icons.play_arrow,
                      size: 20,
                    ),
                    onPressed: () {
                      if (item.status == TurboDownloadStatus.downloading) {
                        turboDownloader.pauseDownload(item.id);
                      } else {
                        turboDownloader.resumeDownload(item.id);
                      }
                      setState(() => _loadData());
                    },
                    tooltip: item.status == TurboDownloadStatus.downloading ? 'Pause' : 'Resume',
                  ),
                  // Cancel
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.red),
                    onPressed: () => turboDownloader.cancelDownload(item.id),
                    tooltip: 'Cancel',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQueueCard(TurboDownloadItem item, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.queue, color: Colors.purple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatSize(item.totalSize),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            onPressed: () => turboDownloader.resumeDownload(item.id),
            tooltip: 'Start',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => turboDownloader.cancelDownload(item.id),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(TurboDownloadItem item, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${_formatSize(item.totalSize)} • ${item.formattedPeakSpeed} peak',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle, color: Colors.blue),
            onPressed: () => _openFile(item),
            tooltip: 'Open',
          ),
        ],
      ),
    );
  }

  Widget _buildShowMoreButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DownloadHistoryScreen()),
        ),
        child: const Text('View All History →'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_download,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '🚀 No Downloads Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste a URL above to start downloading\nwith Turbo Speed!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(ThemeData theme) {
    return FloatingActionButton.extended(
      onPressed: () => _showBatchImport(),
      backgroundColor: Colors.blue,
      icon: const Icon(Icons.library_add),
      label: const Text('Batch'),
    );
  }

  void _showBatchImport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BatchImportScreen(
          onImport: (urls) {
            for (final url in urls) {
              turboDownloader.download(url);
            }
            setState(() => _loadData());
          },
        ),
      ),
    );
  }
}
