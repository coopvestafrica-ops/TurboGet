import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/ad_manager.dart';
import 'services/auth_service.dart';
import 'services/media_detector_service.dart';
import 'models/download_item.dart';
import 'screens/login_screen.dart';
import 'screens/admin_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    AdManager().initialize(),
    AuthService.instance.initialize(),
  ]);
  runApp(const MyApp());
}



class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const MethodChannel _method = MethodChannel('com.example.downloader/methods');
  static const EventChannel _events = EventChannel('com.example.downloader/events');

  final List<DownloadItem> _queue = [];
  StreamSubscription<dynamic>? _eventSub;
  final TextEditingController _urlController = TextEditingController();
  
  // Services
  final _authService = AuthService.instance;
  final _adManager = AdManager();
  
  // Ad related fields
  BannerAd? _bannerAd;
  int _downloadCount = 0; // Track downloads to show interstitial ads

  bool get _shouldShowAds => _authService.currentUser?.shouldShowAds ?? true;

  final _mediaDetector = MediaDetectorService();

  @override
  void initState() {
    super.initState();
    _startListening();
    _initAds();
    _initMediaDetection();
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
    if (_downloadCount % 3 == 0) { // Show ad every 3 downloads
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
            
            if (event['bytes'] != null) {
              final bytes = event['bytes'] as int;
              item.downloadedSize = bytes;
              item.updateSpeed(bytes);
            }
            
            if (event['total_size'] != null) {
              item.totalSize = event['total_size'] as int;
            }
            
            if (status == 'complete') {
              _queue.removeAt(idx);
              _showInterstitialAd(); // Show ad on download completion
            }
          }
        });
      }
    }, onError: (e) {
      // ignore: avoid_print
      print('Event channel error: $e');
    });
  }

  Timer? _clipboardCheckTimer;

  Future<void> _initMediaDetection() async {
    await _mediaDetector.initialize();
    // Start periodic clipboard check
    _clipboardCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        await _mediaDetector.detectAndShowMedia(data!.text!);
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _urlController.dispose();
    _mediaDetector.dispose();
    _clipboardCheckTimer?.cancel();
    super.dispose();
  }

  Future<String> _getDownloadPath() async {
    final dir = await getExternalStorageDirectory();
    final path = dir?.path ?? (await getApplicationDocumentsDirectory()).path;
    return path;
  }

  String _idFromUrl(String url) => url.hashCode.toString();

  Future<void> _addDownload(String url) async {
    final id = _idFromUrl(url);
    final filename = url.split('/').last.split('?').first;
    final item = DownloadItem(
      id: id,
      url: url,
      filename: filename,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      status: 'queued',
      downloadedSize: 0,
    );
    setState(() => _queue.add(item));

    final destPath = await _getDownloadPath();
    try {
      await _method.invokeMethod('startDownload', {
        'id': id,
        'url': url,
        'dest': '$destPath/$filename',
      });
      setState(() {
        final idx = _queue.indexWhere((d) => d.id == id);
        if (idx != -1) _queue[idx].status = 'downloading';
      });
      _showInterstitialAd(); // Show ad after starting download
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('startDownload failed: ${e.message}');
      setState(() {
        final idx = _queue.indexWhere((d) => d.id == id);
        if (idx != -1) _queue[idx].status = 'failed';
      });
    }
  }

  Future<void> _pauseDownload(DownloadItem item) async {
    try {
      await _method.invokeMethod('pauseDownload', {'id': item.id});
      setState(() => item.status = 'paused');
    } catch (e) {
      // ignore: avoid_print
      print('pause error: $e');
    }
  }

  Future<void> _resumeDownload(DownloadItem item) async {
    try {
      await _method.invokeMethod('resumeDownload', {'id': item.id});
      setState(() => item.status = 'downloading');
    } catch (e) {
      // ignore: avoid_print
      print('resume error: $e');
    }
  }

  Future<void> _cancelDownload(DownloadItem item) async {
    try {
      await _method.invokeMethod('cancelDownload', {'id': item.id});
      setState(() => item.status = 'cancelled');
    } catch (e) {
      // ignore: avoid_print
      print('cancel error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter IDM Starter',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('TurboGet'),
          actions: [
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
                    setState(() => _initAds()); // Refresh ads based on new user status
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
                Expanded(child: TextField(controller: _urlController, decoration: const InputDecoration(hintText: 'Enter file URL'))),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () {
                  final url = _urlController.text.trim();
                  if (url.isNotEmpty) _addDownload(url);
                }, child: const Text('Download'))
              ]),
              const SizedBox(height: 12),
              Expanded(child: ListView.builder(
                itemCount: _queue.length,
                itemBuilder: (context, i) {
                  final item = _queue[i];
                  return Card(
                    child: ListTile(
                      title: Text(item.filename),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: (item.progress / 100.0).clamp(0.0, 1.0)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${item.progress}% • ${item.status}'),
                            if (item.status == 'downloading')
                              Text(
                                '${item.formattedSpeed} • ${item.estimatedTimeRemaining}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                        if (item.status == 'downloading')
                          Text('${item.formattedSpeed} • ${item.estimatedTimeRemaining}', 
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                      trailing: PopupMenuButton<String>(onSelected: (v) async {
                        if (v == 'pause') await _pauseDownload(item);
                        if (v == 'resume') await _resumeDownload(item);
                        if (v == 'cancel') await _cancelDownload(item);
                      }, itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'pause', child: Text('Pause')),
                        PopupMenuItem(value: 'resume', child: Text('Resume')),
                        PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                      ]),
                    ),
                  );
                },
              ))
            ],
          ),
        ),
      ),
    );
  }
}
