import 'dart:io';
import 'package:flutter/foundation.dart';

/// Log level enum for categorizing log messages
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// App-wide logging service with support for multiple output targets.
/// 
/// Features:
/// - Timestamped log entries
/// - Log level filtering
/// - Stack trace capture for errors
/// - File output for production debugging
/// - Debug mode toggle
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  bool _isDebugMode = kDebugMode;
  List<LogOutput> _outputs = [];
  
  /// Initialize the logger with optional custom outputs
  Future<void> initialize({
    LogLevel? minLevel,
    bool enableFileOutput = false,
    String? logDirectory,
  }) async {
    _minLevel = minLevel ?? (kDebugMode ? LogLevel.debug : LogLevel.info);
    _isDebugMode = kDebugMode;
    
    // Always add console output
    _outputs.add(ConsoleLogOutput());
    
    // Add file output if enabled
    if (enableFileOutput && logDirectory != null) {
      _outputs.add(FileLogOutput(logDirectory));
    }
    
    await _log(LogLevel.info, 'LoggerService', 'Logger initialized in ${kDebugMode ? "debug" : "release"} mode');
  }

  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  void enableDebugMode() {
    _isDebugMode = true;
    _minLevel = LogLevel.debug;
  }

  void disableDebugMode() {
    _isDebugMode = false;
    _minLevel = LogLevel.info;
  }

  Future<void> _log(
    LogLevel level,
    String tag,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) async {
    if (level.index < _minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(8);
    final formattedMessage = '[$timestamp] $levelStr [$tag] $message';

    for (final output in _outputs) {
      await output.write(
        level: level,
        tag: tag,
        message: message,
        timestamp: timestamp,
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Print to console in debug mode
    if (kDebugMode) {
      if (error != null) {
        debugPrint('$formattedMessage\nError: $error');
        if (stackTrace != null) {
          debugPrintStack(stackTrace: stackTrace);
        }
      } else {
        debugPrint(formattedMessage);
      }
    }
  }

  Future<void> debug(String tag, String message) async {
    await _log(LogLevel.debug, tag, message);
  }

  Future<void> info(String tag, String message) async {
    await _log(LogLevel.info, tag, message);
  }

  Future<void> warning(String tag, String message, {dynamic error, StackTrace? stackTrace}) async {
    await _log(LogLevel.warning, tag, message, error: error, stackTrace: stackTrace);
  }

  Future<void> error(String tag, String message, {dynamic error, StackTrace? stackTrace}) async {
    await _log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace);
  }

  Future<void> critical(String tag, String message, {dynamic error, StackTrace? stackTrace}) async {
    await _log(LogLevel.critical, tag, message, error: error, stackTrace: stackTrace);
  }

  /// Log a caught exception with optional context
  Future<void> logException(
    String tag,
    Object exception, {
    String? context,
    StackTrace? stackTrace,
  }) async {
    final message = context != null 
        ? 'Exception in $context: $exception'
        : 'Exception: $exception';
    
    await _log(
      LogLevel.error,
      tag,
      message,
      error: exception,
      stackTrace: stackTrace ?? StackTrace.current,
    );
  }

  /// Clear all log outputs
  Future<void> dispose() async {
    for (final output in _outputs) {
      await output.dispose();
    }
    _outputs.clear();
  }
}

/// Abstract base class for log outputs
abstract class LogOutput {
  Future<void> write({
    required LogLevel level,
    required String tag,
    required String message,
    required String timestamp,
    dynamic error,
    StackTrace? stackTrace,
  });
  
  Future<void> dispose() async {}
}

/// Console log output
class ConsoleLogOutput implements LogOutput {
  @override
  Future<void> write({
    required LogLevel level,
    required String tag,
    required String message,
    required String timestamp,
    dynamic error,
    StackTrace? stackTrace,
  }) async {
    final levelStr = level.name.toUpperCase().padRight(8);
    final formattedMessage = '[$timestamp] $levelStr [$tag] $message';
    
    if (level == LogLevel.error || level == LogLevel.critical) {
      // Use stderr for errors
      stderr.writeln(formattedMessage);
      if (error != null) {
        stderr.writeln('Error: $error');
      }
    } else {
      stdout.writeln(formattedMessage);
    }
  }

  @override
  Future<void> dispose() async {}
}

/// File log output for production debugging
class FileLogOutput implements LogOutput {
  final String _logDirectory;
  File? _currentLogFile;
  String? _currentLogDate;

  FileLogOutput(this._logDirectory);

  Future<File> _getLogFile() async {
    final today = DateTime.now().toIso8601String().split('T').first;
    
    if (_currentLogDate != today || _currentLogFile == null) {
      final dir = Directory(_logDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      _currentLogDate = today;
      _currentLogFile = File('$dir/turboget_$today.log');
    }
    
    return _currentLogFile!;
  }

  @override
  Future<void> write({
    required LogLevel level,
    required String tag,
    required String message,
    required String timestamp,
    dynamic error,
    StackTrace? stackTrace,
  }) async {
    try {
      final file = await _getLogFile();
      final buffer = StringBuffer();
      buffer.writeln('[$timestamp] ${level.name.toUpperCase().padRight(8)} [$tag] $message');
      
      if (error != null) {
        buffer.writeln('  Error: $error');
      }
      if (stackTrace != null) {
        buffer.writeln('  StackTrace: $stackTrace');
      }
      
      await file.writeAsString(buffer.toString(), mode: FileMode.append);
    } catch (e) {
      // Silently fail file writing to prevent crashes
      stderr.writeln('Failed to write to log file: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _currentLogFile = null;
    _currentLogDate = null;
  }
}

/// Global logger instance
final logger = LoggerService();

/// Extension for easy logging on any class
extension LoggerExtension on Object {
  void logDebug(String message) => logger.debug(runtimeType.toString(), message);
  void logInfo(String message) => logger.info(runtimeType.toString(), message);
  void logWarning(String message, {dynamic error, StackTrace? stackTrace}) => 
      logger.warning(runtimeType.toString(), message, error: error, stackTrace: stackTrace);
  void logError(String message, {dynamic error, StackTrace? stackTrace}) => 
      logger.error(runtimeType.toString(), message, error: error, stackTrace: stackTrace);
  void logCritical(String message, {dynamic error, StackTrace? stackTrace}) => 
      logger.critical(runtimeType.toString(), message, error: error, stackTrace: stackTrace);
  void logException(Object exception, {String? context, StackTrace? stackTrace}) =>
      logger.logException(runtimeType.toString(), exception, context: context, stackTrace: stackTrace);
}
