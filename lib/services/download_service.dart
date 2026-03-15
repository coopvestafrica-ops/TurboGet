import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DownloadService {
  static const MethodChannel _method = MethodChannel('com.example.downloader/methods');
  
  // Singleton pattern
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  bool _isWifiOnly = false;

  Future<bool> requestPermissions() async {
    if (await Permission.storage.request().isGranted) {
      return true;
    }
    return false;
  }

  Future<void> initialize() async {
    // Request permissions
    await requestPermissions();
    
    // Monitor connectivity changes
    _connectivitySub = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    if (_isWifiOnly && result != ConnectivityResult.wifi) {
      // Pause all downloads if wifi-only is enabled and we're not on wifi
      pauseAllDownloads();
    } else if (result != ConnectivityResult.none) {
      // Resume downloads if we have connectivity
      resumeAllDownloads();
    }
  }

  Future<void> setWifiOnlyMode(bool wifiOnly) async {
    _isWifiOnly = wifiOnly;
    if (wifiOnly) {
      final results = await _connectivity.checkConnectivity();
      final connectivity = results.isNotEmpty ? results.first : ConnectivityResult.none;
      if (connectivity != ConnectivityResult.wifi) {
        await pauseAllDownloads();
      }
    }
  }

  Future<void> pauseAllDownloads() async {
    try {
      await _method.invokeMethod('pauseAllDownloads');
    } catch (e) {
      print('Error pausing downloads: $e');
    }
  }

  Future<void> resumeAllDownloads() async {
    if (_isWifiOnly) {
      final results = await _connectivity.checkConnectivity();
      final connectivity = results.isNotEmpty ? results.first : ConnectivityResult.none;
      if (connectivity != ConnectivityResult.wifi) {
        return; // Don't resume if we're not on wifi in wifi-only mode
      }
    }
    
    try {
      await _method.invokeMethod('resumeAllDownloads');
    } catch (e) {
      print('Error resuming downloads: $e');
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
