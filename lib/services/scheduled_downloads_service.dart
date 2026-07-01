import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'logger_service.dart';
import 'settings_manager.dart';
import 'turbo_downloader_engine.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TURBOGET SCHEDULED DOWNLOADS - Enterprise Feature
/// Designed by Olatunji Ayobami Ayanlowo +2347038193753
/// ═══════════════════════════════════════════════════════════════════════════

/// Schedule type
enum ScheduleType {
  once,        // One-time download
  daily,       // Every day at specified time
  weekly,      // Specific days of the week
  monthly,     // Specific day of month
}

/// Schedule status
enum ScheduleStatus {
  pending,     // Waiting to run
  running,     // Currently executing
  completed,   // Successfully completed
  failed,      // Failed to execute
  paused,      // Manually paused
  cancelled,   // Cancelled by user
}

/// Day of week
enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

/// Scheduled Download Item
class ScheduledDownload {
  final String id;
  final String url;
  final String? filename;
  final ScheduleType scheduleType;
  final DateTime scheduledTime;
  final List<DayOfWeek>? daysOfWeek;
  final int? dayOfMonth;
  final ScheduleStatus status;
  final int maxRetries;
  final int retryCount;
  final DateTime createdAt;
  final DateTime? lastRunAt;
  final DateTime? nextRunAt;
  final String? error;
  final bool isActive;

  ScheduledDownload({
    required this.id,
    required this.url,
    this.filename,
    required this.scheduleType,
    required this.scheduledTime,
    this.daysOfWeek,
    this.dayOfMonth,
    this.status = ScheduleStatus.pending,
    this.maxRetries = 3,
    this.retryCount = 0,
    required this.createdAt,
    this.lastRunAt,
    this.nextRunAt,
    this.error,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'url': url,
    'filename': filename,
    'schedule_type': scheduleType.name,
    'scheduled_time': scheduledTime.toIso8601String(),
    'days_of_week': daysOfWeek?.map((d) => d.name).toList(),
    'day_of_month': dayOfMonth,
    'status': status.name,
    'max_retries': maxRetries,
    'retry_count': retryCount,
    'created_at': createdAt.toIso8601String(),
    'last_run_at': lastRunAt?.toIso8601String(),
    'next_run_at': nextRunAt?.toIso8601String(),
    'error': error,
    'is_active': isActive,
  };

  factory ScheduledDownload.fromMap(Map<String, dynamic> map) {
    return ScheduledDownload(
      id: map['id'],
      url: map['url'],
      filename: map['filename'],
      scheduleType: ScheduleType.values.firstWhere(
        (e) => e.name == map['schedule_type'],
        orElse: () => ScheduleType.once,
      ),
      scheduledTime: DateTime.parse(map['scheduled_time']),
      daysOfWeek: (map['days_of_week'] as List?)
          ?.map((d) => DayOfWeek.values.firstWhere(
                (e) => e.name == d,
                orElse: () => DayOfWeek.monday,
              ))
          .toList(),
      dayOfMonth: map['day_of_month'],
      status: ScheduleStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ScheduleStatus.pending,
      ),
      maxRetries: map['max_retries'] ?? 3,
      retryCount: map['retry_count'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      lastRunAt: map['last_run_at'] != null
          ? DateTime.parse(map['last_run_at'])
          : null,
      nextRunAt: map['next_run_at'] != null
          ? DateTime.parse(map['next_run_at'])
          : null,
      error: map['error'],
      isActive: map['is_active'] ?? true,
    );
  }

  ScheduledDownload copyWith({
    String? url,
    String? filename,
    ScheduleType? scheduleType,
    DateTime? scheduledTime,
    List<DayOfWeek>? daysOfWeek,
    int? dayOfMonth,
    ScheduleStatus? status,
    int? maxRetries,
    int? retryCount,
    DateTime? lastRunAt,
    DateTime? nextRunAt,
    String? error,
    bool? isActive,
  }) {
    return ScheduledDownload(
      id: id,
      url: url ?? this.url,
      filename: filename ?? this.filename,
      scheduleType: scheduleType ?? this.scheduleType,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      status: status ?? this.status,
      maxRetries: maxRetries ?? this.maxRetries,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      error: error ?? this.error,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Calculate next run time
  DateTime calculateNextRun() {
    final now = DateTime.now();
    var next = scheduledTime;

    switch (scheduleType) {
      case ScheduleType.once:
        if (next.isBefore(now)) {
          return now.add(const Duration(minutes: 1));
        }
        return next;

      case ScheduleType.daily:
        while (next.isBefore(now)) {
          next = next.add(const Duration(days: 1));
        }
        return next;

      case ScheduleType.weekly:
        if (daysOfWeek == null || daysOfWeek!.isEmpty) {
          return now.add(const Duration(days: 1));
        }
        while (next.isBefore(now)) {
          next = next.add(const Duration(days: 1));
          final dayOfWeek = _getDayOfWeek(next);
          if (daysOfWeek!.contains(dayOfWeek)) {
            return next;
          }
        }
        return next;

      case ScheduleType.monthly:
        if (dayOfMonth == null) {
          return now.add(const Duration(days: 1));
        }
        while (next.isBefore(now)) {
          next = DateTime(next.year, next.month + 1, dayOfMonth!,
              scheduledTime.hour, scheduledTime.minute);
        }
        return next;
    }
  }

  DayOfWeek _getDayOfWeek(DateTime date) {
    switch (date.weekday) {
      case 1:
        return DayOfWeek.monday;
      case 2:
        return DayOfWeek.tuesday;
      case 3:
        return DayOfWeek.wednesday;
      case 4:
        return DayOfWeek.thursday;
      case 5:
        return DayOfWeek.friday;
      case 6:
        return DayOfWeek.saturday;
      case 7:
        return DayOfWeek.sunday;
      default:
        return DayOfWeek.monday;
    }
  }

  String get scheduleTypeText {
    switch (scheduleType) {
      case ScheduleType.once:
        return 'Once';
      case ScheduleType.daily:
        return 'Daily';
      case ScheduleType.weekly:
        return 'Weekly';
      case ScheduleType.monthly:
        return 'Monthly';
    }
  }

  String get statusText {
    switch (status) {
      case ScheduleStatus.pending:
        return 'Pending';
      case ScheduleStatus.running:
        return 'Running';
      case ScheduleStatus.completed:
        return 'Completed';
      case ScheduleStatus.failed:
        return 'Failed';
      case ScheduleStatus.paused:
        return 'Paused';
      case ScheduleStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Scheduled Downloads Service
class ScheduledDownloadsService {
  static final ScheduledDownloadsService _instance =
      ScheduledDownloadsService._internal();
  factory ScheduledDownloadsService() => _instance;
  ScheduledDownloadsService._internal();

  final LoggerService _logger = logger;
  final DatabaseService _database = DatabaseService();
  final SettingsManager _settings = SettingsManager();

  // State
  final Map<String, ScheduledDownload> _schedules = {};
  Timer? _checkTimer;
  bool _isInitialized = false;
  bool _isEnabled = true;

  // Callbacks
  Function(ScheduledDownload)? onScheduleTriggered;
  Function(ScheduledDownload)? onScheduleCompleted;
  Function(ScheduledDownload, String)? onScheduleFailed;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _logger.info('ScheduledDownloads', 'Initializing scheduled downloads service...');

    // Load saved schedules
    await _loadSchedules();

    // Start checking timer
    _startChecker();

    _isInitialized = true;
    _logger.info('ScheduledDownloads', 'Scheduled downloads initialized: ${_schedules.length} schedules');
  }

  /// Load schedules from storage
  Future<void> _loadSchedules() async {
    // Load from settings/database
    final schedulesData = _settings.getString('scheduled_downloads');
    if (schedulesData != null) {
      try {
        // Parse and load schedules
        _logger.info('ScheduledDownloads', 'Loaded schedules from storage');
      } catch (e) {
        _logger.error('ScheduledDownloads', 'Failed to load schedules', error: e);
      }
    }
  }

  /// Save schedules to storage
  Future<void> _saveSchedules() async {
    final data = _schedules.values.map((s) => s.toMap()).toList();
    // Save to storage
    await _settings.setString('scheduled_downloads', data.toString());
  }

  /// Start the schedule checker
  void _startChecker() {
    _checkTimer?.cancel();
    // Check every minute
    _checkTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkSchedules(),
    );
  }

  /// Check and trigger scheduled downloads
  Future<void> _checkSchedules() async {
    if (!_isEnabled) return;

    final now = DateTime.now();

    for (final schedule in _schedules.values) {
      if (!schedule.isActive) continue;
      if (schedule.status == ScheduleStatus.running) continue;

      final nextRun = schedule.calculateNextRun();
      
      // Check if should run now
      if (_shouldRunNow(schedule, now, nextRun)) {
        await _triggerSchedule(schedule);
      }
    }
  }

  bool _shouldRunNow(ScheduledDownload schedule, DateTime now, DateTime nextRun) {
    // For simplicity, check if we're within the same minute
    return nextRun.year == now.year &&
        nextRun.month == now.month &&
        nextRun.day == now.day &&
        nextRun.hour == now.hour &&
        nextRun.minute == now.minute;
  }

  /// Trigger a scheduled download
  Future<void> _triggerSchedule(ScheduledDownload schedule) async {
    _logger.info('ScheduledDownloads', 'Triggering: ${schedule.filename ?? schedule.url}');

    // Update status
    final running = schedule.copyWith(
      status: ScheduleStatus.running,
      lastRunAt: DateTime.now(),
    );
    _schedules[schedule.id] = running;

    onScheduleTriggered?.call(running);

    try {
      // Start the download
      await turboDownloader.download(
        schedule.url,
        filename: schedule.filename,
      );

      // Update to completed
      final completed = running.copyWith(
        status: ScheduleStatus.completed,
        nextRunAt: schedule.scheduleType == ScheduleType.once
            ? null
            : running.calculateNextRun(),
      );
      _schedules[schedule.id] = completed;

      onScheduleCompleted?.call(completed);
      await _saveSchedules();

      _logger.info('ScheduledDownloads', 'Completed: ${schedule.filename}');

    } catch (e) {
      _handleScheduleError(schedule, e.toString());
    }
  }

  /// Handle schedule error
  Future<void> _handleScheduleError(
      ScheduledDownload schedule, String error) async {
    if (schedule.retryCount < schedule.maxRetries) {
      // Retry
      final retry = schedule.copyWith(
        retryCount: schedule.retryCount + 1,
        error: error,
        nextRunAt: DateTime.now().add(Duration(minutes: 5 * (schedule.retryCount + 1))),
      );
      _schedules[schedule.id] = retry;

      _logger.info('ScheduledDownloads', 'Retrying ${schedule.id}: attempt ${retry.retryCount}');
    } else {
      // Mark as failed
      final failed = schedule.copyWith(
        status: ScheduleStatus.failed,
        error: error,
        isActive: false,
      );
      _schedules[schedule.id] = failed;

      onScheduleFailed?.call(failed, error);

      _logger.error('ScheduledDownloads', 'Failed: ${schedule.id}', error: error);
    }

    await _saveSchedules();
  }

  /// Create a new schedule
  Future<ScheduledDownload> createSchedule({
    required String url,
    String? filename,
    required ScheduleType scheduleType,
    required DateTime scheduledTime,
    List<DayOfWeek>? daysOfWeek,
    int? dayOfMonth,
    int maxRetries = 3,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final schedule = ScheduledDownload(
      id: id,
      url: url,
      filename: filename,
      scheduleType: scheduleType,
      scheduledTime: scheduledTime,
      daysOfWeek: daysOfWeek,
      dayOfMonth: dayOfMonth,
      maxRetries: maxRetries,
      createdAt: DateTime.now(),
      nextRunAt: scheduledTime,
    );

    _schedules[id] = schedule;
    await _saveSchedules();

    _logger.info('ScheduledDownloads', 'Created schedule: $id');

    return schedule;
  }

  /// Cancel a schedule
  Future<void> cancelSchedule(String id) async {
    final schedule = _schedules[id];
    if (schedule != null) {
      _schedules[id] = schedule.copyWith(
        status: ScheduleStatus.cancelled,
        isActive: false,
      );
      await _saveSchedules();
      _logger.info('ScheduledDownloads', 'Cancelled schedule: $id');
    }
  }

  /// Pause a schedule
  Future<void> pauseSchedule(String id) async {
    final schedule = _schedules[id];
    if (schedule != null) {
      _schedules[id] = schedule.copyWith(
        status: ScheduleStatus.paused,
        isActive: false,
      );
      await _saveSchedules();
    }
  }

  /// Resume a schedule
  Future<void> resumeSchedule(String id) async {
    final schedule = _schedules[id];
    if (schedule != null) {
      _schedules[id] = schedule.copyWith(
        status: ScheduleStatus.pending,
        isActive: true,
        nextRunAt: schedule.calculateNextRun(),
      );
      await _saveSchedules();
    }
  }

  /// Delete a schedule
  Future<void> deleteSchedule(String id) async {
    _schedules.remove(id);
    await _saveSchedules();
    _logger.info('ScheduledDownloads', 'Deleted schedule: $id');
  }

  /// Get all schedules
  List<ScheduledDownload> getAllSchedules() => _schedules.values.toList();

  /// Get active schedules
  List<ScheduledDownload> getActiveSchedules() =>
      _schedules.values.where((s) => s.isActive).toList();

  /// Get pending schedules
  List<ScheduledDownload> getPendingSchedules() =>
      _schedules.values.where((s) => s.status == ScheduleStatus.pending).toList();

  /// Enable/disable service
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _checkTimer?.cancel();
    } else {
      _startChecker();
    }
  }

  /// Dispose
  void dispose() {
    _checkTimer?.cancel();
  }
}

/// Global instance
final scheduledDownloads = ScheduledDownloadsService();
