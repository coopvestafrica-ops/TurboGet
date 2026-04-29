import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static const String _keyWifiOnly = 'wifiOnly';
  static const String _keyMaxConcurrent = 'maxConcurrent';
  static const String _keyDownloadPath = 'downloadPath';
  static const String _keySchedulerEnabled = 'schedulerEnabled';
  static const String _keySchedulerStartHour = 'schedulerStartHour';
  static const String _keySchedulerStartMinute = 'schedulerStartMinute';
  static const String _keySchedulerEndHour = 'schedulerEndHour';
  static const String _keySchedulerEndMinute = 'schedulerEndMinute';
  static const String _keyBandwidthKbps = 'bandwidthKbps';
  static const String _keyAccentColor = 'accentColorValue';
  static const String _keyLocale = 'locale';

  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get isWifiOnly => _prefs?.getBool(_keyWifiOnly) ?? false;
  set isWifiOnly(bool value) => _prefs?.setBool(_keyWifiOnly, value);

  int get maxConcurrentDownloads => _prefs?.getInt(_keyMaxConcurrent) ?? 3;
  set maxConcurrentDownloads(int value) => _prefs?.setInt(_keyMaxConcurrent, value);

  String? get customDownloadPath => _prefs?.getString(_keyDownloadPath);
  set customDownloadPath(String? value) {
    if (value != null) {
      _prefs?.setString(_keyDownloadPath, value);
    } else {
      _prefs?.remove(_keyDownloadPath);
    }
  }

  /// Bandwidth cap in kilobytes per second. `0` == unlimited.
  int get bandwidthKbps => _prefs?.getInt(_keyBandwidthKbps) ?? 0;
  set bandwidthKbps(int value) => _prefs?.setInt(_keyBandwidthKbps, value);

  /// Bandwidth cap in bytes per second, derived from [bandwidthKbps].
  int get bandwidthBytesPerSecond => bandwidthKbps * 1024;

  /// Accent / seed color stored as a 32-bit ARGB integer. `null` falls
  /// back to the default blue.
  int? get accentColorValue => _prefs?.getInt(_keyAccentColor);
  set accentColorValue(int? value) {
    if (value != null) {
      _prefs?.setInt(_keyAccentColor, value);
    } else {
      _prefs?.remove(_keyAccentColor);
    }
  }

  /// Two-letter locale code (e.g. `en`, `yo`). `null` = follow system.
  String? get localeCode => _prefs?.getString(_keyLocale);
  set localeCode(String? value) {
    if (value != null && value.isNotEmpty) {
      _prefs?.setString(_keyLocale, value);
    } else {
      _prefs?.remove(_keyLocale);
    }
  }

  // Scheduler settings
  bool get schedulerEnabled => _prefs?.getBool(_keySchedulerEnabled) ?? false;
  set schedulerEnabled(bool value) => _prefs?.setBool(_keySchedulerEnabled, value);

  int get schedulerStartHour => _prefs?.getInt(_keySchedulerStartHour) ?? 22; // Default 10 PM
  set schedulerStartHour(int value) => _prefs?.setInt(_keySchedulerStartHour, value);

  int get schedulerStartMinute => _prefs?.getInt(_keySchedulerStartMinute) ?? 0;
  set schedulerStartMinute(int value) => _prefs?.setInt(_keySchedulerStartMinute, value);

  int get schedulerEndHour => _prefs?.getInt(_keySchedulerEndHour) ?? 6; // Default 6 AM
  set schedulerEndHour(int value) => _prefs?.setInt(_keySchedulerEndHour, value);

  int get schedulerEndMinute => _prefs?.getInt(_keySchedulerEndMinute) ?? 0;
  set schedulerEndMinute(int value) => _prefs?.setInt(_keySchedulerEndMinute, value);

  bool isSchedulerActive() {
    if (!schedulerEnabled) return false;
    
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = schedulerStartHour * 60 + schedulerStartMinute;
    final endMinutes = schedulerEndHour * 60 + schedulerEndMinute;
    
    if (startMinutes <= endMinutes) {
      // Same day schedule (e.g., 9:00 - 17:00)
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      // Overnight schedule (e.g., 22:00 - 6:00)
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
  }
}
