import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_manager.dart';
import '../services/download_service.dart';

/// App settings state
class SettingsState {
  final bool isWifiOnly;
  final int maxConcurrentDownloads;
  final String? customDownloadPath;
  final bool schedulerEnabled;
  final int schedulerStartHour;
  final int schedulerStartMinute;
  final int schedulerEndHour;
  final int schedulerEndMinute;
  final bool isLoading;
  final String? errorMessage;

  const SettingsState({
    this.isWifiOnly = false,
    this.maxConcurrentDownloads = 3,
    this.customDownloadPath,
    this.schedulerEnabled = false,
    this.schedulerStartHour = 22,
    this.schedulerStartMinute = 0,
    this.schedulerEndHour = 6,
    this.schedulerEndMinute = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  SettingsState copyWith({
    bool? isWifiOnly,
    int? maxConcurrentDownloads,
    String? customDownloadPath,
    bool? schedulerEnabled,
    int? schedulerStartHour,
    int? schedulerStartMinute,
    int? schedulerEndHour,
    int? schedulerEndMinute,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SettingsState(
      isWifiOnly: isWifiOnly ?? this.isWifiOnly,
      maxConcurrentDownloads: maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      customDownloadPath: customDownloadPath ?? this.customDownloadPath,
      schedulerEnabled: schedulerEnabled ?? this.schedulerEnabled,
      schedulerStartHour: schedulerStartHour ?? this.schedulerStartHour,
      schedulerStartMinute: schedulerStartMinute ?? this.schedulerStartMinute,
      schedulerEndHour: schedulerEndHour ?? this.schedulerEndHour,
      schedulerEndMinute: schedulerEndMinute ?? this.schedulerEndMinute,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  bool get isSchedulerActive {
    if (!schedulerEnabled) return false;
    
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = schedulerStartHour * 60 + schedulerStartMinute;
    final endMinutes = schedulerEndHour * 60 + schedulerEndMinute;
    
    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
  }
}

/// Settings notifier for managing app settings
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsManager _settingsManager;
  final DownloadService _downloadService;

  SettingsNotifier(this._settingsManager, this._downloadService) : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    state = state.copyWith(isLoading: true);
    try {
      await _settingsManager.initialize();
      state = SettingsState(
        isWifiOnly: _settingsManager.isWifiOnly,
        maxConcurrentDownloads: _settingsManager.maxConcurrentDownloads,
        customDownloadPath: _settingsManager.customDownloadPath,
        schedulerEnabled: _settingsManager.schedulerEnabled,
        schedulerStartHour: _settingsManager.schedulerStartHour,
        schedulerStartMinute: _settingsManager.schedulerStartMinute,
        schedulerEndHour: _settingsManager.schedulerEndHour,
        schedulerEndMinute: _settingsManager.schedulerEndMinute,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load settings: $e',
      );
    }
  }

  void setWifiOnly(bool value) {
    _settingsManager.isWifiOnly = value;
    _downloadService.setWifiOnlyMode(value);
    state = state.copyWith(isWifiOnly: value);
  }

  void setMaxConcurrentDownloads(int value) {
    if (value >= 1 && value <= 10) {
      _settingsManager.maxConcurrentDownloads = value;
      state = state.copyWith(maxConcurrentDownloads: value);
    }
  }

  void setCustomDownloadPath(String? value) {
    _settingsManager.customDownloadPath = value;
    state = state.copyWith(customDownloadPath: value);
  }

  void setSchedulerEnabled(bool value) {
    _settingsManager.schedulerEnabled = value;
    state = state.copyWith(schedulerEnabled: value);
  }

  void setSchedulerStartTime(int hour, int minute) {
    _settingsManager.schedulerStartHour = hour;
    _settingsManager.schedulerStartMinute = minute;
    state = state.copyWith(
      schedulerStartHour: hour,
      schedulerStartMinute: minute,
    );
  }

  void setSchedulerEndTime(int hour, int minute) {
    _settingsManager.schedulerEndHour = hour;
    _settingsManager.schedulerEndMinute = minute;
    state = state.copyWith(
      schedulerEndHour: hour,
      schedulerEndMinute: minute,
    );
  }
}

/// Provider for SettingsManager
final settingsManagerProvider = Provider<SettingsManager>((ref) {
  return SettingsManager();
});

/// Provider for DownloadService
final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService();
});

/// Provider for SettingsNotifier
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final settingsManager = ref.watch(settingsManagerProvider);
  final downloadService = ref.watch(downloadServiceProvider);
  return SettingsNotifier(settingsManager, downloadService);
});

/// Convenience providers for individual settings
final isWifiOnlyProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).isWifiOnly;
});

final maxConcurrentDownloadsProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).maxConcurrentDownloads;
});

final schedulerEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).schedulerEnabled;
});

final schedulerActiveProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).isSchedulerActive;
});
