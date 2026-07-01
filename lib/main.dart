import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/logger_service.dart';
import 'services/exception_handler.dart';
import 'services/download_scheduler.dart';
import 'services/turbo_downloader_engine.dart';
import 'services/app_theme.dart';
import 'services/ad_manager.dart';
import 'screens/splash_screen.dart';
import 'screens/turbo_dashboard_screen.dart';
import 'providers/providers.dart';

/// Application version info
class AppInfo {
  static const String name = 'TurboGet';
  static const String version = '1.0.0';
  static const String buildNumber = '1';
  static const String environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
}

Future<void> main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize exception handler first
  exceptionHandler.initialize();
  
  // Initialize logger
  final appDocDir = await getApplicationDocumentsDirectory();
  await logger.initialize(
    minLevel: AppInfo.environment == 'production' ? LogLevel.info : LogLevel.debug,
    enableFileOutput: AppInfo.environment == 'production',
    logDirectory: '${appDocDir.path}/logs',
  );
  
  logger.info('AppStartup', 'Starting ${AppInfo.name} v${AppInfo.version} (${AppInfo.environment})');
  
  // Run error handling wrapper
  await exceptionHandler.runGuarded<void>(
    'AppStartup',
    () async {
      // Initialize core services in parallel
      await Future.wait<void>([
        AdManager().initialize(),
        AuthService.instance.initialize(),
        ThemeService.instance.initialize(),
        DownloadScheduler.instance.initialize(),
        turboDownloader.initialize(),
      ]);
      
      logger.info('AppStartup', 'All services initialized successfully');
    },
    context: 'service initialization',
  );
  
  // Run the app with Riverpod
  runApp(
    ProviderScope(
      child: const TurboGetApp(),
    ),
  );
}

class TurboGetApp extends ConsumerWidget {
  const TurboGetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeState.themeMode,
      home: const SplashScreen(),
      // Global error handling for Material widgets
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          logger.error(
            'UI',
            'Widget error: ${details.exceptionAsString()}',
            error: details.exception,
            stackTrace: details.stack,
          );
          return MaterialApp(
            home: _ErrorScreen(error: details.exceptionAsString()),
          );
        };
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

/// Custom error screen for uncaught errors
class _ErrorScreen extends StatelessWidget {
  final String error;
  
  const _ErrorScreen({required this.error});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Something went wrong'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Oops! Something went wrong.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'re sorry for the inconvenience. Please try again or restart the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                logger.info('ErrorScreen', 'User tapped restart');
                SystemNavigator.pop();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Restart App'),
            ),
          ],
        ),
      ),
    );
  }
}
