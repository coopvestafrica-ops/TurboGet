/// Notification Service - Stub implementation
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {}
  Future<void> showDownloadComplete({
    required String downloadId,
    required String filename,
    String? filePath,
    int? fileSize,
  }) async {}
  Future<void> showError(String message) async {}
  Future<void> showDownloadFailed({
    required String downloadId,
    required String filename,
    String? error,
  }) async {}
  Future<void> showDownloadProgress({
    required String downloadId,
    required String filename,
    required int progress,
  }) async {}
}

final notificationService = NotificationService();
