import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'logger_service.dart';
import 'settings_manager.dart';
import 'package:crypto/crypto.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TURBOGET CLOUD SYNC SERVICE - Enterprise Feature
/// Designed by Olatunji Ayobami Ayanlowo +2347038193753
/// ═══════════════════════════════════════════════════════════════════════════

/// Cloud sync status
enum CloudSyncStatus {
  idle,
  syncing,
  success,
  error,
  offline,
}

/// Sync item type
enum SyncItemType {
  download,
  settings,
  bookmark,
  history,
}

/// Sync item data
class SyncItem {
  final String id;
  final SyncItemType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? checksum;
  bool isSynced;

  SyncItem({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.checksum,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'checksum': checksum,
    'is_synced': isSynced,
  };

  factory SyncItem.fromMap(Map<String, dynamic> map) {
    return SyncItem(
      id: map['id'],
      type: SyncItemType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SyncItemType.download,
      ),
      data: Map<String, dynamic>.from(map['data']),
      timestamp: DateTime.parse(map['timestamp']),
      checksum: map['checksum'],
      isSynced: map['is_synced'] ?? false,
    );
  }

  String generateChecksum() {
    final content = jsonEncode(data);
    return md5.convert(utf8.encode(content)).toString();
  }
}

/// Cloud Sync Service - Enterprise Grade
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final LoggerService _logger = logger;
  final DatabaseService _database = DatabaseService();
  final SettingsManager _settings = SettingsManager();

  // Configuration
  String? _apiEndpoint;
  String? _apiKey;
  bool _isEnabled = false;
  bool _autoSync = true;
  int _syncIntervalMinutes = 15;
  
  // State
  CloudSyncStatus _status = CloudSyncStatus.idle;
  DateTime? _lastSyncTime;
  final List<SyncItem> _pendingSync = [];
  final List<SyncItem> _syncHistory = [];
  Timer? _syncTimer;
  StreamSubscription? _changesSubscription;

  // Callbacks
  Function(CloudSyncStatus, double)? onSyncProgress;
  Function(List<SyncItem>)? onSyncComplete;
  Function(String)? onSyncError;

  /// Initialize the service
  Future<void> initialize() async {
    _logger.info('CloudSync', 'Initializing cloud sync service...');
    
    // Load settings
    _apiEndpoint = _settings.getString('cloud_api_endpoint');
    _apiKey = _settings.getString('cloud_api_key');
    _isEnabled = _settings.getBool('cloud_sync_enabled') ?? false;
    _autoSync = _settings.getBool('cloud_auto_sync') ?? true;
    _syncIntervalMinutes = _settings.getInt('cloud_sync_interval') ?? 15;

    if (_isEnabled && _autoSync) {
      _startAutoSync();
    }

    _logger.info('CloudSync', 'Cloud sync initialized: enabled=$_isEnabled');
  }

  /// Enable cloud sync
  Future<void> enable(String apiEndpoint, String apiKey) async {
    _apiEndpoint = apiEndpoint;
    _apiKey = apiKey;
    _isEnabled = true;

    await _settings.setString('cloud_api_endpoint', apiEndpoint);
    await _settings.setString('cloud_api_key', apiKey);
    await _settings.setBool('cloud_sync_enabled', true);

    _startAutoSync();
    await syncNow();

    _logger.info('CloudSync', 'Cloud sync enabled');
  }

  /// Disable cloud sync
  Future<void> disable() async {
    _isEnabled = false;
    _syncTimer?.cancel();
    
    await _settings.setBool('cloud_sync_enabled', false);
    
    _logger.info('CloudSync', 'Cloud sync disabled');
  }

  /// Start auto sync timer
  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: _syncIntervalMinutes),
      (_) => syncNow(),
    );
  }

  /// Sync now
  Future<bool> syncNow() async {
    if (!_isEnabled || _apiEndpoint == null || _apiKey == null) {
      return false;
    }

    if (_status == CloudSyncStatus.syncing) {
      return false;
    }

    try {
      _status = CloudSyncStatus.syncing;
      onSyncProgress?.call(_status, 0);

      // Collect pending items
      final pendingItems = await _collectPendingItems();
      
      if (pendingItems.isEmpty) {
        _status = CloudSyncStatus.success;
        _lastSyncTime = DateTime.now();
        onSyncProgress?.call(_status, 1);
        return true;
      }

      // Upload to cloud
      final progress = await _uploadToCloud(pendingItems);
      
      // Download from cloud
      await _downloadFromCloud();

      _status = CloudSyncStatus.success;
      _lastSyncTime = DateTime.now();
      _pendingSync.clear();
      
      onSyncProgress?.call(_status, 1);
      onSyncComplete?.call(pendingItems);

      _logger.info('CloudSync', 'Sync completed: ${pendingItems.length} items');

      return true;

    } catch (e) {
      _status = CloudSyncStatus.error;
      _logger.error('CloudSync', 'Sync failed', error: e);
      onSyncError?.call(e.toString());
      return false;
    }
  }

  /// Collect items pending sync
  Future<List<SyncItem>> _collectPendingItems() async {
    final items = <SyncItem>[];

    // Get downloads
    final downloads = await _database.getAllDownloads();
    for (final download in downloads) {
      items.add(SyncItem(
        id: 'download_${download['id']}',
        type: SyncItemType.download,
        data: Map<String, dynamic>.from(download),
        timestamp: DateTime.now(),
      ));
    }

    // Get settings
    final settings = _settings.getAllSettings();
    items.add(SyncItem(
      id: 'settings',
      type: SyncItemType.settings,
      data: settings,
      timestamp: DateTime.now(),
    ));

    // Add pending items
    items.addAll(_pendingSync);

    return items;
  }

  /// Upload to cloud
  Future<double> _uploadToCloud(List<SyncItem> items) async {
    if (_apiEndpoint == null || _apiKey == null) return 0;

    double progress = 0;
    final batchSize = 10;

    for (int i = 0; i < items.length; i += batchSize) {
      final batch = items.skip(i).take(batchSize).toList();
      
      final payload = {
        'items': batch.map((item) => item.toMap()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      try {
        final response = await http.post(
          Uri.parse('$_apiEndpoint/sync/upload'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          throw Exception('Upload failed: ${response.statusCode}');
        }

        progress = (i + batch.length) / items.length;
        onSyncProgress?.call(_status, progress);

      } catch (e) {
        _logger.error('CloudSync', 'Batch upload failed', error: e);
      }
    }

    return progress;
  }

  /// Download from cloud
  Future<void> _downloadFromCloud() async {
    if (_apiEndpoint == null || _apiKey == null) return;

    try {
      final response = await http.get(
        Uri.parse('$_apiEndpoint/sync/download'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['items'] as List)
            .map((item) => SyncItem.fromMap(item))
            .toList();

        // Merge with local data
        await _mergeFromCloud(items);
      }

    } catch (e) {
      _logger.error('CloudSync', 'Download failed', error: e);
    }
  }

  /// Merge cloud data with local
  Future<void> _mergeFromCloud(List<SyncItem> items) async {
    for (final item in items) {
      switch (item.type) {
        case SyncItemType.download:
          await _database.insertDownload(item.data);
          break;
        case SyncItemType.settings:
          for (final entry in item.data.entries) {
            await _settings.setString(entry.key, entry.value.toString());
          }
          break;
        default:
          break;
      }
    }
  }

  /// Add item to pending sync
  void addPendingSync(SyncItem item) {
    item.isSynced = false;
    _pendingSync.add(item);
    
    // Auto sync if enabled
    if (_autoSync) {
      syncNow();
    }
  }

  /// Get sync status
  CloudSyncStatus get status => _status;
  
  DateTime? get lastSyncTime => _lastSyncTime;
  
  bool get isEnabled => _isEnabled;
  
  List<SyncItem> get pendingItems => _pendingSync;

  /// Get sync statistics
  Map<String, dynamic> getSyncStats() {
    return {
      'status': _status.name,
      'is_enabled': _isEnabled,
      'auto_sync': _autoSync,
      'last_sync': _lastSyncTime?.toIso8601String(),
      'pending_items': _pendingSync.length,
      'sync_interval': _syncIntervalMinutes,
    };
  }

  /// Dispose
  void dispose() {
    _syncTimer?.cancel();
    _changesSubscription?.cancel();
  }
}

/// Global instance
final cloudSync = CloudSyncService();
