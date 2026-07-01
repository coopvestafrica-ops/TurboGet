import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/download_item.dart';
import '../services/database_service.dart';
import '../services/download_scheduler.dart';
import '../services/best_downloader_service.dart';

/// Download state class
class DownloadState {
  final List<DownloadItem> activeDownloads;
  final List<DownloadItem> queue;
  final List<DownloadItem> history;
  final bool isLoading;
  final String? errorMessage;
  final int totalActiveDownloads;
  final double averageSpeed;

  const DownloadState({
    this.activeDownloads = const [],
    this.queue = const [],
    this.history = const [],
    this.isLoading = false,
    this.errorMessage,
    this.totalActiveDownloads = 0,
    this.averageSpeed = 0,
  });

  DownloadState copyWith({
    List<DownloadItem>? activeDownloads,
    List<DownloadItem>? queue,
    List<DownloadItem>? history,
    bool? isLoading,
    String? errorMessage,
    int? totalActiveDownloads,
    double? averageSpeed,
  }) {
    return DownloadState(
      activeDownloads: activeDownloads ?? this.activeDownloads,
      queue: queue ?? this.queue,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      totalActiveDownloads: totalActiveDownloads ?? this.totalActiveDownloads,
      averageSpeed: averageSpeed ?? this.averageSpeed,
    );
  }
}

/// Download notifier for managing download state
class DownloadNotifier extends StateNotifier<DownloadState> {
  final DatabaseService _databaseService;
  final DownloadScheduler _scheduler;
  StreamSubscription<dynamic>? _eventSubscription;

  DownloadNotifier(this._databaseService, this._scheduler) : super(const DownloadState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      await _loadHistory();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load downloads: $e',
      );
    }
  }

  Future<void> _loadHistory() async {
    final historyMaps = await _databaseService.getDownloadHistory();
    final history = historyMaps.map((map) => DownloadItem.fromMap(map)).toList();
    state = state.copyWith(history: history);
  }

  void addDownload(DownloadItem item) {
    final updatedActive = [...state.activeDownloads, item];
    state = state.copyWith(
      activeDownloads: updatedActive,
      totalActiveDownloads: updatedActive.length,
    );
  }

  void updateDownload(String id, {int? progress, int? downloadedSize, String? status}) {
    final updatedDownloads = state.activeDownloads.map((item) {
      if (item.id == id) {
        if (progress != null) item.progress = progress;
        if (downloadedSize != null) item.downloadedSize = downloadedSize;
        if (status != null) item.status = status;
      }
      return item;
    }).toList();

    // Move completed downloads to history
    final completed = updatedDownloads.where((d) => 
      d.status == 'completed' || d.status == 'failed' || d.status == 'cancelled'
    ).toList();
    
    final stillActive = updatedDownloads.where((d) => 
      d.status != 'completed' && d.status != 'failed' && d.status != 'cancelled'
    ).toList();

    if (completed.isNotEmpty) {
      _loadHistory(); // Refresh history
    }

    state = state.copyWith(
      activeDownloads: stillActive,
      totalActiveDownloads: stillActive.length,
    );
  }

  Future<void> pauseDownload(String id) async {
    try {
      await _scheduler.pauseDownload(id);
      updateDownload(id, status: 'paused');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to pause download: $e');
    }
  }

  Future<void> resumeDownload(String id) async {
    try {
      await _scheduler.resumeDownload(id);
      updateDownload(id, status: 'downloading');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to resume download: $e');
    }
  }

  Future<void> cancelDownload(String id) async {
    try {
      await _scheduler.cancelDownload(id);
      updateDownload(id, status: 'cancelled');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to cancel download: $e');
    }
  }

  Future<void> retryDownload(String id) async {
    try {
      await _scheduler.retryDownload(id);
      updateDownload(id, status: 'downloading');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to retry download: $e');
    }
  }

  Future<void> clearHistory() async {
    try {
      await _databaseService.clearAllDownloads();
      state = state.copyWith(history: []);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to clear history: $e');
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for DatabaseService
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// Provider for DownloadScheduler
final downloadSchedulerProvider = Provider<DownloadScheduler>((ref) {
  return DownloadScheduler.instance;
});

/// Provider for DownloadNotifier
final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final scheduler = ref.watch(downloadSchedulerProvider);
  return DownloadNotifier(databaseService, scheduler);
});

/// Provider for active downloads count
final activeDownloadsCountProvider = Provider<int>((ref) {
  return ref.watch(downloadProvider).totalActiveDownloads;
});

/// Provider for download queue count
final queueCountProvider = Provider<int>((ref) {
  return ref.watch(downloadProvider).queue.length;
});

/// Provider for average download speed
final averageSpeedProvider = Provider<double>((ref) {
  return ref.watch(downloadProvider).averageSpeed;
});
