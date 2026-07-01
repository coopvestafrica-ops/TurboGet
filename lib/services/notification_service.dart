import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'logger_service.dart';

/// Notification service for download progress and completion
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final LoggerService _logger = logger;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  final Map<String, int> _activeNotifications = {};

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permission
      await _requestPermission();

      // Android initialization
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      _logger.info('NotificationService', 'Initialized successfully');
    } catch (e) {
      _logger.error('NotificationService', 'Failed to initialize', error: e);
    }
  }

  Future<void> _requestPermission() async {
    try {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        _logger.info('NotificationService', 'Notification permission granted');
      } else {
        _logger.info('NotificationService', 'Notification permission denied');
      }
    } catch (e) {
      _logger.error('NotificationService', 'Failed to request permission', error: e);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    final payload = response.payload;
    if (payload != null) {
      _logger.info('NotificationService', 'Notification tapped: $payload');
    }
  }

  /// Show download progress notification
  Future<void> showDownloadProgress({
    required String downloadId,
    required String filename,
    required int progress,
    required int downloadedBytes,
    required int totalBytes,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final notificationId = _activeNotifications[downloadId] ?? 
          DateTime.now().millisecondsSinceEpoch % 100000;
      _activeNotifications[downloadId] = notificationId;

      final androidDetails = AndroidNotificationDetails(
        'download_progress',
        'Download Progress',
        channelDescription: 'Shows download progress',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: 100,
        progress: progress,
        ongoing: true,
        autoCancel: false,
        category: AndroidNotificationCategory.progress,
        visibility: NotificationVisibility.public,
        actions: [
          const AndroidNotificationAction(
            'pause',
            'Pause',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'cancel',
            'Cancel',
            showsUserInterface: true,
          ),
        ],
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final speed = _formatSpeed(downloadedBytes);
      await _notifications.show(
        notificationId,
        'Downloading: $filename',
        '$progress% • $speed',
        details,
        payload: downloadId,
      );
    } catch (e) {
      _logger.error('NotificationService', 'Failed to show progress notification', error: e);
    }
  }

  /// Show download completed notification
  Future<void> showDownloadComplete({
    required String downloadId,
    required String filename,
    required String filePath,
    required int fileSize,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      // Cancel progress notification
      final notificationId = _activeNotifications[downloadId];
      if (notificationId != null) {
        await _notifications.cancel(notificationId);
        _activeNotifications.remove(downloadId);
      }

      final androidDetails = AndroidNotificationDetails(
        'download_complete',
        'Download Complete',
        channelDescription: 'Download completion notifications',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.progress,
        autoCancel: true,
        actions: [
          const AndroidNotificationAction(
            'open',
            'Open',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'share',
            'Share',
            showsUserInterface: true,
          ),
        ],
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final newNotificationId = DateTime.now().millisecondsSinceEpoch % 100000;

      await _notifications.show(
        newNotificationId,
        'Download Complete',
        '$filename (${_formatSize(fileSize)})',
        details,
        payload: filePath,
      );
    } catch (e) {
      _logger.error('NotificationService', 'Failed to show completion notification', error: e);
    }
  }

  /// Show download failed notification
  Future<void> showDownloadFailed({
    required String downloadId,
    required String filename,
    required String error,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      // Cancel progress notification
      final notificationId = _activeNotifications[downloadId];
      if (notificationId != null) {
        await _notifications.cancel(notificationId);
        _activeNotifications.remove(downloadId);
      }

      final androidDetails = AndroidNotificationDetails(
        'download_failed',
        'Download Failed',
        channelDescription: 'Download failure notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
        actions: [
          const AndroidNotificationAction(
            'retry',
            'Retry',
            showsUserInterface: true,
          ),
        ],
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final newNotificationId = DateTime.now().millisecondsSinceEpoch % 100000;

      await _notifications.show(
        newNotificationId,
        'Download Failed',
        '$filename: $error',
        details,
        payload: downloadId,
      );
    } catch (e) {
      _logger.error('NotificationService', 'Failed to show failed notification', error: e);
    }
  }

  /// Cancel a download notification
  Future<void> cancelDownloadNotification(String downloadId) async {
    try {
      final notificationId = _activeNotifications[downloadId];
      if (notificationId != null) {
        await _notifications.cancel(notificationId);
        _activeNotifications.remove(downloadId);
      }
    } catch (e) {
      _logger.error('NotificationService', 'Failed to cancel notification', error: e);
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    try {
      await _notifications.cancelAll();
      _activeNotifications.clear();
    } catch (e) {
      _logger.error('NotificationService', 'Failed to cancel all notifications', error: e);
    }
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Global notification service instance
final notificationService = NotificationService();