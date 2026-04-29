import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_manager.dart';

/// App theming. Extends [ChangeNotifier] so UI wrapped in a
/// [ListenableBuilder] rebuilds when the theme changes at runtime.
///
/// Reads the seed/accent color from [SettingsManager] so the user can
/// pick their own from Settings → Accent Color and the change applies
/// across the whole app immediately.
class ThemeService extends ChangeNotifier {
  /// Public hook so screens that mutate global state outside this
  /// service (e.g. the locale picker in Settings) can ask
  /// [MaterialApp] to rebuild.
  @override
  void notifyListeners() => super.notifyListeners();

  static const String _themeKey = 'theme_mode';
  static const Color defaultSeed = Colors.blue;

  /// Curated accent palette shown in Settings → Accent color.
  static const List<Color> accentPalette = <Color>[
    Colors.blue,
    Colors.indigo,
    Colors.deepPurple,
    Colors.teal,
    Colors.green,
    Colors.amber,
    Colors.deepOrange,
    Colors.pink,
    Colors.red,
  ];

  static ThemeService? _instance;
  static ThemeService get instance => _instance ??= ThemeService._();
  ThemeService._();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Color get seedColor {
    final raw = SettingsManager().accentColorValue;
    return raw != null ? Color(raw) : defaultSeed;
  }

  Future<void> setSeedColor(Color color) async {
    SettingsManager().accentColorValue = (color.a * 255).round() << 24
        | (color.r * 255).round() << 16
        | (color.g * 255).round() << 8
        | (color.b * 255).round();
    notifyListeners();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_themeKey);
    if (idx != null && idx >= 0 && idx < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[idx];
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  ThemeData get lightTheme => _buildTheme(Brightness.light);
  ThemeData get darkTheme => _buildTheme(Brightness.dark);

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
