import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/download_item.dart';
import '../services/media_type_service.dart';
import '../services/auth_service.dart';
import '../services/ad_manager.dart';
import '../services/download_scheduler.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';
import '../services/best_downloader_service.dart';
import '../providers/providers.dart';
import '../providers/best_downloader_provider.dart';
import 'login_screen.dart';
import 'admin_panel.dart';
import 'settings_screen.dart';
import 'download_history_screen.dart';
import 'file_browser_screen.dart';
import 'batch_import_screen.dart';
import 'about_screen.dart';
import 'media_player_screen.dart';

/// Beautiful professional dashboard screen
/// Designed by Ayanlowo Olatunji Ayobami
/// Email: ayanlowo89@gmail.com | WhatsApp: +2347038193753
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final MediaTypeService _mediaType = MediaTypeService();
  final DatabaseService _database = DatabaseService();
  final BestDownloaderService _bestDownloader = bestDownloader;

  List<DownloadItem> _activeDownloads = [];
  List<DownloadItem> _completedDownloads = [];
  StreamSubscription<dynamic>? _eventSub;
  Timer? _clipboardTimer;
  bool _isDownloading = false;
  int _totalSpeed = 0;

  // Animation controllers
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  late AnimationController _pulseController;

  // Stats
  int _totalDownloads = 0;
  int _completedCount = 0;
  int _todayDownloads = 0;
  int _totalSize = 0;
  int _activeCount = 0;
  int _pausedCount = 0;

  final _authService = AuthService.instance;
  final _adManager = AdManager();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOutBack,
    );
    _fabAnimationController.forward();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize best downloader
      await _bestDownloader.initialize();
      
      // Set up callbacks
      _bestDownloader.onProgress = (download) {
        if (mounted) setState(() {});
      };
      
      _bestDownloader.onComplete = (download) {
        if (mounted) {
          setState(() {});
          _showDownloadCompleteSnackbar(download);
        }
      };
      
      _bestDownloader.onError = (download, error) {
        if (mounted) setState(() {});
      };

      // Resume all paused downloads on startup
      await _bestDownloader.resumeAllPausedDownloads();

      await _loadData();
      _startClipboardMonitoring();
      
      setState(() => _isInitialized = true);
    } catch (e) {
      logger.error('Dashboard', 'Initialization failed', error: e);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _searchController.dispose();
    _urlFocusNode.dispose();
    _eventSub?.cancel();
    _clipboardTimer?.cancel();
    _fabAnimationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final downloads = _bestDownloader.getAllDownloads();
      final active = downloads.where((d) => d.status == DownloadStatus.downloading).toList();
      final paused = downloads.where((d) => d.status == DownloadStatus.paused).toList();
      final completed = downloads.where((d) => d.status == DownloadStatus.completed).toList();

      final today = DateTime.now();
      final todayCount = completed.where((d) {
        final date = DateTime.fromMillisecondsSinceEpoch(d.completedAt ?? d.createdAt);
        return date.year == today.year && date.month == today.month && date.day == today.day;
      }).length;

      int totalSizeAll = 0;
      int totalSpeedAll = 0;
      
      for (final d in downloads) {
        totalSizeAll += d.totalSize;
        if (d.status == DownloadStatus.downloading) {
          totalSpeedAll += d.speed.round();
        }
      }

      setState(() {
        _activeDownloads = active.map((d) => _fromPersisted(d)).toList();
        _completedDownloads = completed.map((d) => _fromPersisted(d)).toList();
        _totalDownloads = completed.length;
        _completedCount = completed.length;
        _todayDownloads = todayCount;
        _totalSize = totalSizeAll;
        _totalSpeed = totalSpeedAll;
        _activeCount = active.length;
        _pausedCount = paused.length;
      });
    } catch (e) {
      logger.error('Dashboard', 'Failed to load data', error: e);
    }
  }

  DownloadItem _fromPersisted(PersistedDownload d) {
    return DownloadItem(
      id: d.id,
      url: d.url,
      filename: d.filename,
      downloadPath: d.downloadPath,
      totalSize: d.totalSize,
      downloadedSize: d.downloadedSize,
      progress: d.progress,
      status: d.status.name,
      createdAt: d.createdAt,
      error: d.error,
    );
  }

  void _startClipboardMonitoring() {
    _clipboardTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
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
                  const Text('URL detected in clipboard'),
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
          label: 'Paste',
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

  void _showDownloadCompleteSnackbar(PersistedDownload item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _mediaType.isVideo(item.filename)
                  ? Icons.movie
                  : _mediaType.isAudio(item.filename)
                      ? Icons.music_note
                      : Icons.check_circle,
              color: Colors.green,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${item.filename} downloaded',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => _openFile(item),
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openFile(PersistedDownload item) async {
    if (item.downloadPath != null) {
      if (_mediaType.isPlayable(item.filename)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaPlayerScreen(filePath: item.downloadPath!),
          ),
        );
      }
    }
  }

  Future<void> _startDownload(String url) async {
    if (!_isValidUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _bestDownloader.startDownload(url);
      _urlController.clear();
      await _loadData();
    } catch (e) {
      logger.error('Dashboard', 'Download failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pauseDownload(DownloadItem item) async {
    await _bestDownloader.pauseDownload(item.id);
    await _loadData();
  }

  Future<void> _resumeDownload(DownloadItem item) async {
    await _bestDownloader.resumeDownload(item.id);
    await _loadData();
  }

  Future<void> _cancelDownload(DownloadItem item) async {
    await _bestDownloader.cancelDownload(item.id);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          _buildAppBar(theme, isDark),

          // Stats Cards
          SliverToBoxAdapter(
            child: _buildStatsSection(theme, isDark),
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: _buildQuickActions(theme, isDark),
          ),

          // Download Input
          SliverToBoxAdapter(
            child: _buildDownloadInput(theme, isDark),
          ),

          // Active Downloads Header
          SliverToBoxAdapter(
            child: _buildSectionHeader('Active Downloads', theme),
          ),

          // Active Downloads List
          _activeDownloads.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyDownloads(theme))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildDownloadCard(_activeDownloads[index], theme),
                    childCount: _activeDownloads.length,
                  ),
                ),

          // Completed Downloads Header
          SliverToBoxAdapter(
            child: _buildSectionHeader('Recent Downloads', theme),
          ),

          // Completed Downloads
          _completedDownloads.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyHistory(theme))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildHistoryCard(
                        _completedDownloads[index], theme, isDark),
                    childCount: math.min(_completedDownloads.length, 10),
                  ),
                ),

          // Bottom padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      floatingActionButton: _buildFAB(theme),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAppBar(ThemeData theme, bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : theme.colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'TurboGet',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.8),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Background pattern
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -50,
                bottom: -20,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => _showSearchDialog(),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) => _handleMenuAction(value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'history',
              child: ListTile(
                leading: Icon(Icons.history),
                title: Text('Download History'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'files',
              child: ListTile(
                leading: Icon(Icons.folder),
                title: Text('File Browser'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'about',
              child: ListTile(
                leading: Icon(Icons.info),
                title: Text('About'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.download_done,
                  iconColor: Colors.green,
                  value: _completedCount.toString(),
                  label: 'Completed',
                  theme: theme,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.today,
                  iconColor: Colors.blue,
                  value: _todayDownloads.toString(),
                  label: 'Today',
                  theme: theme,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.speed,
                  iconColor: Colors.orange,
                  value: _formatSpeed(_totalSpeed),
                  label: 'Speed',
                  theme: theme,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.storage,
                  iconColor: Colors.purple,
                  value: _formatSize(_totalSize),
                  label: 'Total',
                  theme: theme,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Active downloads indicator
          if (_activeCount > 0 || _pausedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.1),
                    theme.colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_activeCount > 0) ...[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_activeCount Active',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  if (_activeCount > 0 && _pausedCount > 0)
                    const SizedBox(width: 16),
                  if (_pausedCount > 0) ...[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_pausedCount Paused',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.video_library,
              label: 'Videos',
              color: Colors.red,
              onTap: () => _showBatchImport('video'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.music_note,
              label: 'Audio',
              color: Colors.pink,
              onTap: () => _showBatchImport('audio'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.image,
              label: 'Images',
              color: Colors.teal,
              onTap: () => _showBatchImport('image'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.document_file,
              label: 'Documents',
              color: Colors.indigo,
              onTap: () => _showBatchImport('document'),
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
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.link,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Paste or enter download URL...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (value) => _startDownload(value),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.paste,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      _urlController.text = data!.text!;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _startDownload(_urlController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.download),
                label: const Text(
                  'Start Download',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DownloadHistoryScreen(),
                ),
              );
            },
            child: const Text('See All'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDownloads(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_download_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Downloads',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste a URL above to start downloading',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(DownloadItem item, ThemeData theme) {
    final mediaType = _mediaType.getMediaType(item.filename);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _cancelDownload(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // File type icon with progress
              Stack(
                alignment: Alignment.center,
                children: [
                  CircularPercentIndicator(
                    radius: 28,
                    lineWidth: 4,
                    percent: (item.progress / 100).clamp(0.0, 1.0),
                    progressColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                    center: Text(
                      '${item.progress}%',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        mediaType?.icon ?? '📄',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.filename,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StatusChip(
                          status: item.status,
                          theme: theme,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.formattedSpeed}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_formatSize(item.downloadedSize)} / ${_formatSize(item.totalSize ?? 0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.status == 'downloading')
                    IconButton(
                      icon: const Icon(Icons.pause_circle, color: Colors.orange),
                      onPressed: () => _pauseDownload(item),
                    )
                  else if (item.status == 'paused')
                    IconButton(
                      icon: const Icon(Icons.play_circle, color: Colors.green),
                      onPressed: () => _resumeDownload(item),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _cancelDownload(item),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(DownloadItem item, ThemeData theme, bool isDark) {
    final mediaType = _mediaType.getMediaType(item.filename);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getFileColor(item.filename).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            mediaType?.icon ?? '📄',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          item.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${_formatSize(item.totalSize ?? 0)} • ${_formatDate(item.createdAt)}',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (value) => _handleHistoryAction(value, item),
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
              value: 'redownload',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Download Again'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => _openFile(item),
      ),
    );
  }

  Widget _buildEmptyHistory(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No download history yet',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(ThemeData theme) {
    return ScaleTransition(
      scale: _fabAnimation,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showBatchImport(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Batch Import',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Downloads'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Enter filename...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement search
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'history':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DownloadHistoryScreen()),
        );
        break;
      case 'files':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FileBrowserScreen()),
        );
        break;
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
      case 'about':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        );
        break;
    }
  }

  void _handleHistoryAction(String action, DownloadItem item) {
    switch (action) {
      case 'open':
        _openFile(item);
        break;
      case 'share':
        // Implement share
        break;
      case 'redownload':
        _startDownload(item.url);
        break;
    }
  }

  void _showBatchImport([String? type]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BatchImportScreen(
          onImport: (urls) {
            for (final url in urls) {
              _startDownload(url);
            }
          },
        ),
      ),
    );
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
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getFileColor(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    if (['mp4', 'mkv', 'avi', 'mov', 'wmv'].contains(ext)) {
      return Colors.red;
    }
    if (['mp3', 'wav', 'aac', 'flac', 'ogg'].contains(ext)) {
      return Colors.pink;
    }
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return Colors.teal;
    }
    if (['pdf', 'doc', 'docx', 'txt'].contains(ext)) {
      return Colors.indigo;
    }
    return Colors.grey;
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final ThemeData theme;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// Quick Action Button
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Status Chip Widget
class _StatusChip extends StatelessWidget {
  final String status;
  final ThemeData theme;

  const _StatusChip({required this.status, required this.theme});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'downloading':
        color = Colors.blue;
        label = 'Downloading';
        break;
      case 'paused':
        color = Colors.orange;
        label = 'Paused';
        break;
      case 'completed':
        color = Colors.green;
        label = 'Complete';
        break;
      case 'failed':
        color = Colors.red;
        label = 'Failed';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
