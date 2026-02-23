import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static const String _keyWifiOnly = 'wifiOnly';
  static const String _keyMaxConcurrent = 'maxConcurrent';
  static const String _keyDownloadPath = 'downloadPath';

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
}
