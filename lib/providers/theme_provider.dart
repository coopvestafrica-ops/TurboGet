import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/theme_service.dart';

/// Theme state class
class ThemeState {
  final ThemeMode themeMode;
  final bool isLoading;

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.isLoading = false,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? isLoading,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Theme notifier for managing app theme
class ThemeNotifier extends StateNotifier<ThemeState> {
  final ThemeService _themeService;

  ThemeNotifier(this._themeService) : super(const ThemeState()) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    state = state.copyWith(isLoading: true);
    await _themeService.initialize();
    state = ThemeState(
      themeMode: _themeService.themeMode,
      isLoading: false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _themeService.setThemeMode(mode);
    state = state.copyWith(themeMode: mode);
  }

  void toggleTheme() {
    final newMode = state.themeMode == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    setThemeMode(newMode);
  }
}

/// Provider for ThemeService
final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService.instance;
});

/// Provider for ThemeNotifier
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  final themeService = ref.watch(themeServiceProvider);
  return ThemeNotifier(themeService);
});

/// Convenience provider for current theme mode
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeProvider).themeMode;
});

/// Convenience provider for light theme
final lightThemeProvider = Provider<ThemeData>((ref) {
  final themeService = ref.watch(themeServiceProvider);
  return themeService.lightTheme;
});

/// Convenience provider for dark theme
final darkThemeProvider = Provider<ThemeData>((ref) {
  final themeService = ref.watch(themeServiceProvider);
  return themeService.darkTheme;
});
