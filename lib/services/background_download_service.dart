import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/download_item.dart';

class BackgroundDownloadService {
  static BackgroundDownloadService? _instance;
  static BackgroundDownloadService get instance => _instance ??= BackgroundDownloadService._();
  BackgroundDownloadService._();

  bool _isInitialized = false;
  final _activeTasks = <String, DownloadTask>{};
  
  Function(DownloadTaskStatus, int, int)? onTaskProgress;
  Function(String)? onTaskComplete;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await FlutterDownloader.initialize(
      debug: false,
    );

    FlutterDownloader.registerCallback((id, status, progress) {
      _handleProgress(id, status, progress);
    });

    _isInitialized = true;
  }

  void _handleProgress(String id, int status, int progress) {
    final task = _activeTasks[id];
    if (task != null) {
      onTaskProgress?.call(
        DownloadTaskStatus(status),
        progress,
        task.progress,
      );
      
      if (status == DownloadTaskStatus.complete.index) {
        onTaskComplete?.call(id);
        _activeTasks.remove(id);
      }
    }
  }

  Future<bool> requestPermissions() async {
    // Request storage permission for Android
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
    
    // For Android 13+, need manage external storage for full access
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
    
    return true;
  }

  Future<String?> enqueueDownload(DownloadItem item) async {
    if (!_isInitialized) await initialize();
    
    await requestPermissions();

    final dir = await getExternalStorageDirectory();
    final savePath = '${dir?.path}/Download/${item.filename}';

    final taskId = await FlutterDownloader.enqueue(
      url: item.url,
      savedDir: '${dir?.path}/Download',
      fileName: item.filename,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: true,
    );

    if (taskId != null) {
      _activeTasks[taskId] = DownloadTask(
        id: taskId,
        url: item.url,
        filename: item.filename,
        progress: 0,
        status: DownloadTaskStatus.enqueued,
      );
    }

    return taskId;
  }

  Future<void> pauseDownload(String taskId) async {
    await FlutterDownloader.pause(taskId: taskId);
  }

  Future<void> resumeDownload(String taskId) async {
    await FlutterDownloader.resume(taskId: taskId);
  }

  Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
    _activeTasks.remove(taskId);
  }

  Future<void> cancelAll() async {
    await FlutterDownloader.cancelAll();
    _activeTasks.clear();
  }

  List<DownloadTask> getActiveTasks() {
    return _activeTasks.values.toList();
  }
}

class DownloadTask {
  final String id;
  final String url;
  final String filename;
  int progress;
  DownloadTaskStatus status;

  DownloadTask({
    required this.id,
    required this.url,
    required this.filename,
    required this.progress,
    required this.status,
  });
}

enum DownloadTaskStatus {
  undefined,
  enqueued,
  running,
  paused,
  completed,
  failed,
  cancelled,
  pending,
}

extension DownloadTaskStatusExtension on DownloadTaskStatus {
  static DownloadTaskStatus fromIndex(int index) {
    return DownloadTaskStatus.values[index.clamp(0, DownloadTaskStatus.values.length - 1)];
  }
}
