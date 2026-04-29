import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'l10n/app_localizations.dart';
import 'services/ad_manager.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/settings_manager.dart';
import 'services/theme_service.dart';
import 'services/download_scheduler.dart';
import 'models/download_item.dart';
import 'screens/login_screen.dart';
import 'screens/admin_panel.dart';
import 'screens/first_run_setup_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/download_history_screen.dart';
import 'screens/file_browser_screen.dart';
import 'screens/batch_import_screen.dart';
import 'widgets/conflict_dialog.dart';

/// Master switch for AdMob. Flip to `true` (and re-add
/// `AdManager().initialize()` to `main`) when monetization is ready.
const bool kAdsEnabled = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait<void>([
    if (kAdsEnabled) AdManager().initialize(),
    AuthService.instance.initialize(),
    SettingsManager().initialize(),
    ThemeService.instance.initialize(),
    DownloadScheduler.instance.initialize(),
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to ThemeService so theme changes propagate live.
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final theme = ThemeService.instance;
        final localeCode = SettingsManager().localeCode;
        return MaterialApp(
          title: 'TurboGet',
          debugShowCheckedModeBanner: false,
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.themeMode,
          locale: localeCode != null ? Locale(localeCode) : null,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AuthService.instance.needsInitialSetup
              ? const FirstRunSetupScreen()
              : const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _method =
      MethodChannel('com.example.downloader/methods');
  static const EventChannel _events =
      EventChannel('com.example.downloader/events');
  static const MethodChannel _share =
      MethodChannel('com.example.turboget/share');

  final List<DownloadItem> _queue = [];
  StreamSubscription<dynamic>? _eventSub;
  final TextEditingController _urlController = TextEditingController();

  final _authService = AuthService.instance;
  final _adManager = AdManager();
  final _scheduler = DownloadScheduler.instance;
  final _settings = SettingsManager();
  final _db = DatabaseService();

  BannerAd? _bannerAd;
  int _downloadCount = 0;

  bool get _shouldShowAds =>
      kAdsEnabled && (_authService.currentUser?.shouldShowAds ?? true);

  Timer? _clipboardCheckTimer;
  String? _lastClipboardSuggestion;

  @override
  void initState() {
    super.initState();
    _restoreQueue();
    _startListening();
    _initAds();
    _initClipboardMonitor();
    _initShareHandler();
    _initScheduler();
  }

  /// Loads any unfinished downloads from the DB and shows them as
  /// `paused` so the user can resume manually after relaunching the
  /// app. We don't auto-resume because the OS may have killed our
  /// process and the underlying URL might have expired (e.g. signed
  /// CDN tokens).
  Future<void> _restoreQueue() async {
    try {
      final rows = await _db.getActiveDownloads();
      if (rows.isEmpty) return;
      final restored = <DownloadItem>[];
      for (final row in rows) {
        final item = DownloadItem.fromMap(row);
        if (item.status == 'downloading') item.status = 'paused';
        restored.add(item);
      }
      if (!mounted) return;
      setState(() => _queue.addAll(restored));
    } catch (e) {
      debugPrint('Failed to restore queue: $e');
    }
  }

  void _initAds() {
    if (_shouldShowAds) {
      _bannerAd = _adManager.createBannerAd()..load();
      _adManager.loadInterstitialAd();
    }
  }

  void _showInterstitialAd() {
    if (!_shouldShowAds) return;
    _downloadCount++;
    if (_downloadCount % 3 == 0) {
      _adManager.showInterstitialAd();
    }
  }

  void _startListening() {
    _eventSub = _events.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final id = event['id'] ?? event['url'];
        final rawProgress = event['progress'] ?? 0;
        int progress = 0;
        if (rawProgress is num) {
          progress = rawProgress.toInt();
        } else if (rawProgress is String) {
          progress = int.tryParse(rawProgress) ?? 0;
        }
        final status = (event['status'] ?? 'downloading').toString();
        setState(() {
          final idx = _queue.indexWhere((d) => d.id == id);
          if (idx != -1) {
            final item = _queue[idx];
            item.progress = progress;
            item.status = status;

            if (event['bytes'] != null || event['downloaded'] != null) {
              final bytes =
                  (event['bytes'] ?? event['downloaded']) as int? ?? 0;
              item.downloadedSize = bytes;
              item.updateSpeed(bytes);
            }

            if (event['total_size'] != null || event['total'] != null) {
              item.totalSize =
                  (event['total_size'] ?? event['total']) as int?;
            }

            // Persist progress at most once a second, plus on terminal
            // status changes — we don't want to thrash sqlite.
            if (status == 'completed' ||
                status == 'failed' ||
                status == 'cancelled' ||
                progress % 5 == 0) {
              _db.updateDownload(item.id, item.toMap()).catchError(
                    (e) => debugPrint('persist error: $e'),
                  );
            }

            if (status == 'completed' || status == 'complete') {
              _queue.removeAt(idx);
              _showInterstitialAd();
            }
          }
        });
      }
    }, onError: (Object e) {
      debugPrint('Event channel error: $e');
    });
  }

  // Clipboard monitor: shows a SnackBar prompting to add detected URLs
  // instead of enqueueing them automatically (which was surprising
  // behaviour and could download things the user never asked for).
  Future<void> _initClipboardMonitor() async {
    _clipboardCheckTimer =
        Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return;
      if (text == _lastClipboardSuggestion) return;

      final url = _firstUrlIn(text);
      if (url == null) return;
      if (_queue.any((d) => d.url == url)) return;
      _lastClipboardSuggestion = url;

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('URL detected: $url'),
          action: SnackBarAction(
            label: 'ADD',
            onPressed: () => _addDownload(url),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    });
  }

  String? _firstUrlIn(String text) {
    final re = RegExp(
      r'https?:\/\/[^\s<>"]+',
      caseSensitive: false,
    );
    final match = re.firstMatch(text);
    return match?.group(0);
  }

  // Listens for Android share-sheet intents forwarded by MainActivity via
  // MethodChannel. When the user shares a URL to TurboGet from another
  // app, we surface it in the URL field instead of enqueueing silently.
  Future<void> _initShareHandler() async {
    _share.setMethodCallHandler((call) async {
      if (call.method == 'sharedUrl') {
        final url = (call.arguments as String?)?.trim();
        if (url != null && url.isNotEmpty && mounted) {
          setState(() => _urlController.text = url);
        }
      }
      return null;
    });
    // Pull any pending shared URL received before the handler was set.
    try {
      final pending = await _share.invokeMethod<String>('getInitialSharedUrl');
      if (pending != null && pending.isNotEmpty && mounted) {
        setState(() => _urlController.text = pending);
      }
    } on MissingPluginException {
      // Platform channel not available (non-Android) — ignore.
    } on PlatformException catch (e) {
      debugPrint('getInitialSharedUrl failed: ${e.message}');
    }
  }

  void _initScheduler() {
    _scheduler.onSchedulerStatusChanged = (status) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scheduler: $status')),
        );
      }
    };
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _urlController.dispose();
    _clipboardCheckTimer?.cancel();
    _scheduler.pauseAllScheduled();
    super.dispose();
  }

  Future<String> _getDownloadPath() async {
    final custom = _settings.customDownloadPath;
    if (custom != null && custom.isNotEmpty) return custom;
    final dir = await getExternalStorageDirectory();
    final path = dir?.path ?? (await getApplicationDocumentsDirectory()).path;
    return path;
  }

  String _idFromUrl(String url) =>
      '${url.hashCode}_${DateTime.now().millisecondsSinceEpoch}';

  /// Returns a destination filename that doesn't already exist, by
  /// asking the user via [showConflictDialog] when a collision is
  /// detected. Returns `null` if the user picked Skip.
  Future<String?> _resolveFilename(String dirPath, String filename) async {
    final exists = await File('$dirPath/$filename').exists();
    if (!exists) return filename;
    if (!mounted) return null;
    final action = await showConflictDialog(context, filename);
    if (action == null || action == ConflictAction.skip) return null;
    if (action == ConflictAction.overwrite) {
      // Best effort: drop any sidecar or stale file.
      try {
        await File('$dirPath/$filename').delete();
        await File('$dirPath/$filename.tg.json').delete();
      } catch (_) {}
      return filename;
    }
    // rename: pick the next free numbered variant ("foo (1).bin").
    final dot = filename.lastIndexOf('.');
    final base = dot == -1 ? filename : filename.substring(0, dot);
    final ext = dot == -1 ? '' : filename.substring(dot);
    var i = 1;
    while (await File('$dirPath/$base ($i)$ext').exists()) {
      i++;
    }
    return '$base ($i)$ext';
  }

  Future<void> _addDownload(String url, {String? sha256}) async {
    final destDir = await _getDownloadPath();
    final rawName = url.split('/').last.split('?').first;
    final desired = rawName.isEmpty ? 'download' : rawName;
    final filename = await _resolveFilename(destDir, desired);
    if (filename == null) return;

    final id = _idFromUrl(url);
    final item = DownloadItem(
      id: id,
      url: url,
      filename: filename,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      status: 'queued',
      downloadedSize: 0,
      sha256: sha256,
      ownerUserId: _authService.currentUser?.id,
      priority: _queue.length,
      downloadPath: '$destDir/$filename',
    );

    setState(() => _queue.add(item));
    try {
      await _db.insertDownload(item.toMap());
    } catch (e) {
      debugPrint('persist insert error: $e');
    }

    try {
      await _method.invokeMethod('startDownload', {
        'id': id,
        'url': url,
        'dest': '$destDir/$filename',
        'sha256': sha256,
        'bytesPerSecond': _settings.bandwidthBytesPerSecond,
      });
      setState(() {
        final idx = _queue.indexWhere((d) => d.id == id);
        if (idx != -1) _queue[idx].status = 'downloading';
      });
      _showInterstitialAd();
    } on MissingPluginException catch (e) {
      debugPrint('Downloader plugin not registered: ${e.message}');
      _markFailed(id);
    } on PlatformException catch (e) {
      debugPrint('startDownload failed: ${e.message}');
      _markFailed(id);
    }
  }

  void _markFailed(String id) {
    setState(() {
      final idx = _queue.indexWhere((d) => d.id == id);
      if (idx != -1) _queue[idx].status = 'failed';
    });
    _db.updateDownload(id, {'status': 'failed'}).catchError(
      (e) => debugPrint('persist fail: $e'),
    );
  }

  Future<void> _addBatchDownloads(List<String> urls) async {
    for (final url in urls) {
      await _addDownload(url);
    }
  }

  Future<void> _pauseDownload(DownloadItem item) async {
    try {
      await _method.invokeMethod('pauseDownload', {'id': item.id});
      setState(() => item.status = 'paused');
      _db.updateDownload(item.id, {'status': 'paused'});
    } catch (e) {
      debugPrint('pause error: $e');
    }
  }

  Future<void> _resumeDownload(DownloadItem item) async {
    // If the native handle has been lost (e.g. the process was killed
    // and we just restored from DB), restart the download — the
    // SegmentedDownloader's `.tg.json` sidecar makes this a true
    // resume from the last persisted offset rather than a from-scratch
    // re-download.
    try {
      final ok = await _method.invokeMethod<bool>('resumeDownload', {
        'id': item.id,
      });
      if (ok == true) {
        setState(() => item.status = 'downloading');
        _db.updateDownload(item.id, {'status': 'downloading'});
        return;
      }
    } catch (_) {}
    final destDir = await _getDownloadPath();
    try {
      await _method.invokeMethod('startDownload', {
        'id': item.id,
        'url': item.url,
        'dest': '$destDir/${item.filename}',
        'sha256': item.sha256,
        'bytesPerSecond': _settings.bandwidthBytesPerSecond,
      });
      setState(() => item.status = 'downloading');
      _db.updateDownload(item.id, {'status': 'downloading'});
    } catch (e) {
      debugPrint('resume start error: $e');
    }
  }

  Future<void> _cancelDownload(DownloadItem item) async {
    try {
      await _method.invokeMethod('cancelDownload', {'id': item.id});
      setState(() => item.status = 'cancelled');
      _db.updateDownload(item.id, {'status': 'cancelled'});
    } catch (e) {
      debugPrint('cancel error: $e');
    }
  }

  void _showBatchImport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BatchImportScreen(onImport: _addBatchDownloads),
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _queue.removeAt(oldIndex);
      _queue.insert(newIndex, item);
      // Re-stamp priorities so the order survives an app restart.
      for (var i = 0; i < _queue.length; i++) {
        _queue[i].priority = i;
        _db.updateDownload(_queue[i].id, {'priority': i}).catchError(
          (e) => debugPrint('priority persist error: $e'),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TurboGet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Download History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DownloadHistoryScreen(
                    onRedownload: _addDownload,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'File Browser',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FileBrowserScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(_authService.isLoggedIn ? Icons.person : Icons.login),
            onPressed: () async {
              if (_authService.isAdmin) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminPanel()),
                );
              } else {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                if (result == true) {
                  setState(() => _initAds());
                }
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            if (_shouldShowAds && _bannerAd != null)
              SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'Enter file URL',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_circle),
                tooltip: 'More options',
                onSelected: (value) {
                  if (value == 'batch') {
                    _showBatchImport();
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem<String>(
                    value: 'batch',
                    child: ListTile(
                      leading: Icon(Icons.playlist_add),
                      title: Text('Batch Import'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final url = _urlController.text.trim();
                  if (url.isNotEmpty) _addDownload(url);
                },
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ),
            const SizedBox(height: 12),
            if (_scheduler.queuedCount > 0)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Scheduled: ${_scheduler.queuedCount} downloads in queue',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_download,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No active downloads',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter a URL or use batch import',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: _queue.length,
                      onReorder: _onReorder,
                      buildDefaultDragHandles: false,
                      itemBuilder: (context, i) {
                        final item = _queue[i];
                        return Card(
                          key: ValueKey(item.id),
                          child: ListTile(
                            leading: ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                            title: Text(item.filename,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.url,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11)),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                      value: (item.progress / 100.0)
                                          .clamp(0.0, 1.0)),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${item.progress}% • ${item.status}'),
                                      if (item.status == 'downloading')
                                        Text(
                                          '${item.formattedSpeed} • ${item.estimatedTimeRemaining}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                    ],
                                  ),
                                ]),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'pause') await _pauseDownload(item);
                                if (v == 'resume') await _resumeDownload(item);
                                if (v == 'cancel') await _cancelDownload(item);
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(
                                    value: 'pause', child: Text('Pause')),
                                PopupMenuItem(
                                    value: 'resume', child: Text('Resume')),
                                PopupMenuItem(
                                    value: 'cancel', child: Text('Cancel')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
