import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';

import 'services/app_theme.dart';
import 'services/turbo_downloader_engine.dart';
import 'services/cloud_sync_service.dart';
import 'services/scheduled_downloads_service.dart';
import 'screens/splash_screen.dart';
import 'screens/turbo_dashboard_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TURBOGET DESKTOP APP - Main Entry Point
/// Designed by Olatunji Ayobami Ayanlowo +2347038193753
/// ═══════════════════════════════════════════════════════════════════════════

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  await windowManager.ensureInitialized();

  // Window options
  const windowOptions = WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(1000, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'TurboGet - Enterprise Download Manager',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Initialize services
  await _initializeServices();

  // Run the app
  runApp(
    const ProviderScope(
      child: TurboGetDesktopApp(),
    ),
  );
}

Future<void> _initializeServices() async {
  // Initialize core services
  await turboDownloader.initialize();
  await cloudSync.initialize();
  await scheduledDownloads.initialize();
}

/// TurboGet Desktop App
class TurboGetDesktopApp extends StatefulWidget {
  const TurboGetDesktopApp({super.key});

  @override
  State<TurboGetDesktopApp> createState() => _TurboGetDesktopAppState();
}

class _TurboGetDesktopAppState extends State<TurboGetDesktopApp> with WindowListener {
  bool _isMaximized = false;
  final SystemTray _systemTray = SystemTray();
  bool _isMinimizedToTray = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initSystemTray();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initSystemTray() async {
    // Initialize system tray
    await _systemTray.initSystemTray(
      title: 'TurboGet',
      iconPath: _getTrayIcon(),
      toolTip: 'TurboGet - Enterprise Download Manager',
    );

    // Create menu
    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Show TurboGet',
        onClicked: (menuItem) => _showWindow(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Start Download',
        onClicked: (menuItem) => _showWindow(),
      ),
      MenuItemLabel(
        label: 'Pause All',
        onClicked: (menuItem) => turboDownloader.pauseDownload,
      ),
      MenuItemLabel(
        label: 'Resume All',
        onClicked: (menuItem) => turboDownloader.resumeAll(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Exit',
        onClicked: (menuItem) => exit(0),
      ),
    ]);

    await _systemTray.setContextMenu(menu);

    // Handle tray icon click
    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick ||
          eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
  }

  String _getTrayIcon() {
    // Use platform-specific icon path
    if (Platform.isWindows) {
      return 'assets/icons/app_icon.ico';
    }
    return 'assets/icons/app_icon.png';
  }

  void _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    _isMinimizedToTray = false;
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  void onWindowClose() async {
    // Minimize to tray instead of closing
    await windowManager.hide();
    _isMinimizedToTray = true;
  }

  @override
  void onWindowMinimize() async {
    // Optionally minimize to tray
    if (_isMinimizedToTray) {
      await windowManager.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TurboGet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );
  }
}

/// Desktop Layout - Sidebar + Content
class DesktopLayout extends StatelessWidget {
  final Widget content;
  final int selectedIndex;
  final Function(int) onItemSelected;

  const DesktopLayout({
    super.key,
    required this.content,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Logo
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppTheme.turboGradient,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 40),
                // Navigation Items
                _buildNavItem(0, Icons.home_rounded, 'Home'),
                _buildNavItem(1, Icons.download_rounded, 'Downloads'),
                _buildNavItem(2, Icons.queue_rounded, 'Queue'),
                _buildNavItem(3, Icons.schedule_rounded, 'Schedule'),
                const Spacer(),
                _buildNavItem(4, Icons.settings_rounded, 'Settings'),
                _buildNavItem(5, Icons.info_rounded, 'About'),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String tooltip) {
    final isSelected = selectedIndex == index;
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onItemSelected(index),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: isSelected ? AppTheme.primaryGradient : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white54,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
