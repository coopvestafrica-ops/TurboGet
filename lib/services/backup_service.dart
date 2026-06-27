import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'database_service.dart';
import 'settings_manager.dart';
import 'logger_service.dart';

/// Service for exporting and importing download history and settings.
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final LoggerService _logger = logger;
  final DatabaseService _databaseService = DatabaseService();
  final SettingsManager _settingsManager = SettingsManager();

  /// Export download history to JSON file
  Future<String?> exportDownloadHistory() async {
    try {
      _logger.info('BackupService', 'Starting download history export');

      // Get all downloads
      final downloads = await _databaseService.getAllDownloads();
      final completed = downloads.where((d) => d['status'] == 'completed').toList();

      // Create backup data
      final backupData = {
        'version': '1.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'downloads': completed.map((d) => {
          'url': d['url'],
          'filename': d['filename'],
          'downloadPath': d['download_path'],
          'totalSize': d['total_size'],
          'completedAt': d['created_at'],
        }).toList(),
      };

      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'turboget_backup_$timestamp.json';
      final filePath = path.join(directory.path, fileName);
      
      final file = File(filePath);
      await file.writeAsString(jsonString);

      _logger.info('BackupService', 'Backup exported to $filePath');
      return filePath;
    } catch (e, stackTrace) {
      _logger.error('BackupService', 'Failed to export download history', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Export all settings to JSON file
  Future<String?> exportSettings() async {
    try {
      _logger.info('BackupService', 'Starting settings export');

      await _settingsManager.initialize();

      final settingsData = {
        'version': '1.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': {
          'isWifiOnly': _settingsManager.isWifiOnly,
          'maxConcurrentDownloads': _settingsManager.maxConcurrentDownloads,
          'customDownloadPath': _settingsManager.customDownloadPath,
          'schedulerEnabled': _settingsManager.schedulerEnabled,
          'schedulerStartHour': _settingsManager.schedulerStartHour,
          'schedulerStartMinute': _settingsManager.schedulerStartMinute,
          'schedulerEndHour': _settingsManager.schedulerEndHour,
          'schedulerEndMinute': _settingsManager.schedulerEndMinute,
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(settingsData);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'turboget_settings_$timestamp.json';
      final filePath = path.join(directory.path, fileName);

      final file = File(filePath);
      await file.writeAsString(jsonString);

      _logger.info('BackupService', 'Settings exported to $filePath');
      return filePath;
    } catch (e, stackTrace) {
      _logger.error('BackupService', 'Failed to export settings', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Export both history and settings
  Future<String?> exportAll() async {
    try {
      _logger.info('BackupService', 'Starting full backup export');

      final downloads = await _databaseService.getAllDownloads();
      final completed = downloads.where((d) => d['status'] == 'completed').toList();

      await _settingsManager.initialize();

      final backupData = {
        'version': '1.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'type': 'full_backup',
        'downloads': completed.map((d) => {
          'url': d['url'],
          'filename': d['filename'],
          'downloadPath': d['download_path'],
          'totalSize': d['total_size'],
          'completedAt': d['created_at'],
        }).toList(),
        'settings': {
          'isWifiOnly': _settingsManager.isWifiOnly,
          'maxConcurrentDownloads': _settingsManager.maxConcurrentDownloads,
          'customDownloadPath': _settingsManager.customDownloadPath,
          'schedulerEnabled': _settingsManager.schedulerEnabled,
          'schedulerStartHour': _settingsManager.schedulerStartHour,
          'schedulerStartMinute': _settingsManager.schedulerStartMinute,
          'schedulerEndHour': _settingsManager.schedulerEndHour,
          'schedulerEndMinute': _settingsManager.schedulerEndMinute,
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'turboget_full_backup_$timestamp.json';
      final filePath = path.join(directory.path, fileName);

      final file = File(filePath);
      await file.writeAsString(jsonString);

      _logger.info('BackupService', 'Full backup exported to $filePath');
      return filePath;
    } catch (e, stackTrace) {
      _logger.error('BackupService', 'Failed to export backup', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Share backup file
  Future<bool> shareBackup(String filePath) async {
    try {
      final file = XFile(filePath);
      await Share.shareXFiles(
        [file],
        subject: 'TurboGet Backup',
        text: 'TurboGet download history and settings backup',
      );
      return true;
    } catch (e) {
      _logger.error('BackupService', 'Failed to share backup', error: e);
      return false;
    }
  }

  /// Import download history from JSON file
  Future<ImportResult> importDownloadHistory(String jsonContent) async {
    try {
      _logger.info('BackupService', 'Starting download history import');

      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      
      // Validate version
      final version = data['version'] as String?;
      if (version == null) {
        return ImportResult(
          success: false,
          message: 'Invalid backup file: missing version',
        );
      }

      final downloads = data['downloads'] as List<dynamic>?;
      if (downloads == null) {
        return ImportResult(
          success: false,
          message: 'Invalid backup file: missing downloads',
        );
      }

      int importedCount = 0;
      for (final download in downloads) {
        final downloadMap = download as Map<String, dynamic>;
        await _databaseService.insertDownload({
          'id': 'imported_${DateTime.now().millisecondsSinceEpoch}_$importedCount',
          'url': downloadMap['url'],
          'filename': downloadMap['filename'],
          'download_path': downloadMap['downloadPath'],
          'total_size': downloadMap['totalSize'],
          'created_at': downloadMap['completedAt'] ?? DateTime.now().millisecondsSinceEpoch,
          'downloaded_size': downloadMap['totalSize'] ?? 0,
          'status': 'completed',
          'progress': 100,
        });
        importedCount++;
      }

      _logger.info('BackupService', 'Imported $importedCount downloads');
      return ImportResult(
        success: true,
        message: 'Successfully imported $importedCount downloads',
        importedCount: importedCount,
      );
    } catch (e, stackTrace) {
      _logger.error('BackupService', 'Failed to import download history', error: e, stackTrace: stackTrace);
      return ImportResult(
        success: false,
        message: 'Failed to import: ${e.toString()}',
      );
    }
  }

  /// Import settings from JSON file
  Future<ImportResult> importSettings(String jsonContent) async {
    try {
      _logger.info('BackupService', 'Starting settings import');

      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final settings = data['settings'] as Map<String, dynamic>?;
      
      if (settings == null) {
        return ImportResult(
          success: false,
          message: 'Invalid settings file: missing settings',
        );
      }

      await _settingsManager.initialize();

      if (settings.containsKey('isWifiOnly')) {
        _settingsManager.isWifiOnly = settings['isWifiOnly'] as bool;
      }
      if (settings.containsKey('maxConcurrentDownloads')) {
        _settingsManager.maxConcurrentDownloads = settings['maxConcurrentDownloads'] as int;
      }
      if (settings.containsKey('customDownloadPath')) {
        _settingsManager.customDownloadPath = settings['customDownloadPath'] as String?;
      }
      if (settings.containsKey('schedulerEnabled')) {
        _settingsManager.schedulerEnabled = settings['schedulerEnabled'] as bool;
      }
      if (settings.containsKey('schedulerStartHour')) {
        _settingsManager.schedulerStartHour = settings['schedulerStartHour'] as int;
      }
      if (settings.containsKey('schedulerStartMinute')) {
        _settingsManager.schedulerStartMinute = settings['schedulerStartMinute'] as int;
      }
      if (settings.containsKey('schedulerEndHour')) {
        _settingsManager.schedulerEndHour = settings['schedulerEndHour'] as int;
      }
      if (settings.containsKey('schedulerEndMinute')) {
        _settingsManager.schedulerEndMinute = settings['schedulerEndMinute'] as int;
      }

      _logger.info('BackupService', 'Settings imported successfully');
      return ImportResult(
        success: true,
        message: 'Settings imported successfully',
      );
    } catch (e, stackTrace) {
      _logger.error('BackupService', 'Failed to import settings', error: e, stackTrace: stackTrace);
      return ImportResult(
        success: false,
        message: 'Failed to import settings: ${e.toString()}',
      );
    }
  }

  /// Import from full backup file
  Future<ImportResult> importFullBackup(String jsonContent) async {
    try {
      _logger.info('BackupService', 'Starting full backup import');

      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type != 'full_backup') {
        return ImportResult(
          success: false,
          message: 'Invalid backup file type',
        );
      }

      // Import downloads
      final downloadsResult = await importDownloadHistory(jsonContent);
      if (!downloadsResult.success) {
        return downloadsResult;
      }

      // Import settings
      final settingsResult = await importSettings(jsonContent);
      if (!settingsResult.success) {
        return settingsResult;
      }

      return ImportResult(
        success: true,
        message: 'Full backup restored successfully',
        importedCount: downloadsResult.importedCount,
      );
    } catch (e, stackTrace) {
      _logger.error('BackupService', 'Failed to import full backup', error: e, stackTrace: stackTrace);
      return ImportResult(
        success: false,
        message: 'Failed to import backup: ${e.toString()}',
      );
    }
  }

  /// Read backup file from path
  Future<String?> readBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      _logger.error('BackupService', 'Failed to read backup file', error: e);
      return null;
    }
  }

  /// Get backup file size
  Future<int> getBackupFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Delete backup file
  Future<bool> deleteBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      _logger.error('BackupService', 'Failed to delete backup file', error: e);
      return false;
    }
  }

  /// List all backup files
  Future<List<BackupFile>> listBackupFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = await directory.list().toList();
      
      final backups = <BackupFile>[];
      for (final file in files) {
        if (file is File && file.path.contains('turboget_') && file.path.endsWith('.json')) {
          final stat = await file.stat();
          final size = stat.size;
          backups.add(BackupFile(
            path: file.path,
            name: path.basename(file.path),
            size: size,
            createdAt: stat.modified,
          ));
        }
      }
      
      // Sort by date, newest first
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return backups;
    } catch (e) {
      _logger.error('BackupService', 'Failed to list backup files', error: e);
      return [];
    }
  }
}

/// Result of an import operation
class ImportResult {
  final bool success;
  final String message;
  final int? importedCount;

  ImportResult({
    required this.success,
    required this.message,
    this.importedCount,
  });
}

/// Represents a backup file
class BackupFile {
  final String path;
  final String name;
  final int size;
  final DateTime createdAt;

  BackupFile({
    required this.path,
    required this.name,
    required this.size,
    required this.createdAt,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Global backup service instance
final backupService = BackupService();
