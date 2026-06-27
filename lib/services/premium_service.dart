import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'logger_service.dart';
import 'database_service.dart';
import 'settings_manager.dart';

/// Premium features service
class PremiumService {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  final LoggerService _logger = logger;
  final DatabaseService _database = DatabaseService();
  final SettingsManager _settings = SettingsManager();

  bool _isPremium = false;
  String? _premiumExpiry;

  /// Check if premium is active
  bool get isPremium => _isPremium;

  /// Initialize premium service
  Future<void> initialize() async {
    await _settings.initialize();
    final isPremium = await _settings.getSetting('is_premium');
    _premiumExpiry = await _settings.getSetting('premium_expiry');
    
    if (isPremium == 'true') {
      if (_premiumExpiry != null) {
        final expiryDate = DateTime.parse(_premiumExpiry!);
        _isPremium = DateTime.now().isBefore(expiryDate);
      } else {
        _isPremium = true;
      }
    }
    
    _logger.info('PremiumService', 'Premium status: $_isPremium');
  }

  /// Activate premium with license key
  Future<bool> activatePremium(String licenseKey) async {
    try {
      // In production, validate with server
      // For now, accept any key that starts with 'TURBO'
      if (licenseKey.startsWith('TURBO') && licenseKey.length >= 10) {
        _isPremium = true;
        // Set expiry to 1 year from now
        final expiry = DateTime.now().add(const Duration(days: 365));
        _premiumExpiry = expiry.toIso8601String();
        
        await _settings.setSetting('is_premium', 'true');
        await _settings.setSetting('premium_expiry', _premiumExpiry!);
        await _settings.setSetting('license_key', licenseKey);
        
        _logger.info('PremiumService', 'Premium activated');
        return true;
      }
      return false;
    } catch (e) {
      _logger.error('PremiumService', 'Failed to activate premium', error: e);
      return false;
    }
  }

  /// Deactivate premium
  Future<void> deactivatePremium() async {
    _isPremium = false;
    _premiumExpiry = null;
    await _settings.setSetting('is_premium', 'false');
    await _settings.deleteSetting('premium_expiry');
    await _settings.deleteSetting('license_key');
    _logger.info('PremiumService', 'Premium deactivated');
  }

  /// Get days remaining
  int get daysRemaining {
    if (!_isPremium || _premiumExpiry == null) return 0;
    final expiry = DateTime.parse(_premiumExpiry!);
    return expiry.difference(DateTime.now()).inDays;
  }
}

/// Premium features
class PremiumFeatures {
  // Free tier limits
  static const int freeMaxConcurrentDownloads = 2;
  static const int freeMaxFileSizeMB = 500;
  static const bool freeShowAds = true;
  static const int freeCloudBackupMB = 100;

  // Premium tier
  static const int premiumMaxConcurrentDownloads = 10;
  static const int premiumMaxFileSizeMB = 10000;
  static const bool premiumShowAds = false;
  static const int premiumCloudBackupMB = 5000;

  /// Check if feature is available
  static bool isFeatureAvailable(PremiumFeature feature, bool isPremium) {
    switch (feature) {
      case PremiumFeature.unlimitedDownloads:
        return isPremium;
      case PremiumFeature.noAds:
        return isPremium;
      case PremiumFeature.cloudBackup:
        return isPremium;
      case PremiumFeature.prioritySupport:
        return isPremium;
      case PremiumFeature.customThemes:
        return isPremium;
      case PremiumFeature.scheduledDownloads:
        return true;
      case PremiumFeature.batchImport:
        return true;
      case PremiumFeature.mediaPlayback:
        return true;
    }
  }
}

enum PremiumFeature {
  unlimitedDownloads,
  noAds,
  cloudBackup,
  prioritySupport,
  customThemes,
  scheduledDownloads,
  batchImport,
  mediaPlayback,
}

/// Global premium service instance
final premiumService = PremiumService();
