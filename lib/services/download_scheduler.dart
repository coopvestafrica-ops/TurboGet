import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/download_item.dart';
import '../services/settings_manager.dart';

class DownloadScheduler {
  static DownloadScheduler? _instance;
  static DownloadScheduler get instance => _instance ??= DownloadScheduler._();
  DownloadScheduler._();

  final _settings = SettingsManager();
  final _connectivity = Connectivity();
  
  final _downloadQueue = <DownloadItem>[];
  Timer? _schedulerTimer;
  Timer? _connectivityTimer;
  bool _isSchedulerActive = false;
  bool _isWifiConnected = false;

  Function(DownloadItem)? onDownloadStart;
  Function(String)? onSchedulerStatusChanged;

  Future<void> initialize() async {
    // Check connectivity    final
 connectivityResult = await _connectivity.checkConnectivity();
    _isWifiConnected = connectivityResult.contains(ConnectivityResult.wifi);

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((results) {
      _isWifiConnected = results.contains(ConnectivityResult.wifi);
      _checkAndStartDownloads();
    });

    // Start scheduler timer
    _startSchedulerTimer();
  }

  void _startSchedulerTimer() {
    // Check every minute if scheduler should be active
    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndStartDownloads();
    });
  }

  bool _isWithinScheduledHours() {
    return _settings.isSchedulerActive();
  }

  bool _canDownloadNow() {
    // If scheduler is not enabled, always allow
    if (!_settings.schedulerEnabled) return true;
    
    // If wifi-only mode and not on wifi, don't download
    if (_settings.isWifiOnly && !_isWifiConnected) return false;
    
    // If within scheduled hours, allow
    if (_isWithinScheduledHours()) return true;
    
    // Outside scheduled hours
    return false;
  }

  void _checkAndStartDownloads() {
    final wasActive = _isSchedulerActive;
    _isSchedulerActive = _canDownloadNow();
    
    // Notify if status changed
    if (wasActive != _isSchedulerActive) {
      onSchedulerStatusChanged?.call(
        _isSchedulerActive ? 'Downloading allowed' : 'Waiting for scheduled time'
      );
    }

    if (_isSchedulerActive && _downloadQueue.isNotEmpty) {
      // Process queue
      _processQueue();
    }
  }

  void queueDownload(DownloadItem item) {
    _downloadQueue.add(item);
    _checkAndStartDownloads();
  }

  void _processQueue() {
    // Process queued downloads
    // This is simplified - in a real app, you'd integrate with your download manager
    while (_downloadQueue.isNotEmpty && _canDownloadNow()) {
      final item = _downloadQueue.removeAt(0);
      onDownloadStart?.call(item);
    }
  }

  void pauseAllScheduled() {
    _schedulerTimer?.cancel();
    _connectivityTimer?.cancel();
  }

  void resume() {
    _startSchedulerTimer();
    _checkAndStartDownloads();
  }

  bool get isActive => _isSchedulerActive;
  int get queuedCount => _downloadQueue.length;
  
  String get statusMessage {
    if (!_settings.schedulerEnabled) return 'Scheduler disabled';
    if (_settings.isWifiOnly && !_isWifiConnected) return 'Waiting for Wi-Fi';
    if (_isWithinScheduledHours()) return 'Active';
    return 'Waiting for scheduled time (${_formatTime(_settings.schedulerStartHour, _settings.schedulerStartMinute)} - ${_formatTime(_settings.schedulerEndHour, _settings.schedulerEndMinute)})';
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
