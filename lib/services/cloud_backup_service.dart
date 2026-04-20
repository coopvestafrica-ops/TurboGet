import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';

class CloudBackupService {
  static CloudBackupService? _instance;
  static CloudBackupService get instance => _instance ??= CloudBackupService._();
  CloudBackupService._();

  String? _lastBackupDate;

  // In a real app, you'd use Firebase, AWS, or your own backend
  // For now, we'll simulate cloud backup using SharedPreferences
  
  Future<bool> backupHistory(List<DownloadItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert items to JSON
      final jsonList = items.map((item) => {
        'id': item.id,
        'url': item.url,
        'filename': item.filename,
        'status': item.status,
        'progress': item.progress,
        'totalSize': item.totalSize,
        'downloadedSize': item.downloadedSize,
        'createdAt': item.createdAt,
      }).toList();

      // Save to cloud storage (simulated)
      await prefs.setString('cloud_backup_history', jsonEncode(jsonList));
      _lastBackupDate = DateTime.now().toIso8601String();
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>?> restoreHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupData = prefs.getString('cloud_backup_history');
      
      if (backupData == null) return null;
      
      final List<dynamic> jsonList = jsonDecode(backupData);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('cloud_backup_history');
  }

  String? get lastBackupDate => _lastBackupDate;

  // Auto-backup settings
  Future<void> enableAutoBackup({int intervalHours = 24}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', true);
    await prefs.setInt('auto_backup_interval', intervalHours);
  }

  Future<void> disableAutoBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', false);
  }

  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_backup_enabled') ?? false;
  }

  Future<int> getAutoBackupInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('auto_backup_interval') ?? 24;
  }
}
