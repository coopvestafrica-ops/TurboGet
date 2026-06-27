import 'dart:async';
import 'package:flutter/foundation.dart';
import 'logger_service.dart';

/// Global exception handler for the app.
/// Catches uncaught exceptions and reports them appropriately.
class ExceptionHandler {
  static final ExceptionHandler _instance = ExceptionHandler._internal();
  factory ExceptionHandler() => _instance;
  ExceptionHandler._internal();

  final LoggerService _logger = logger;
  bool _isInitialized = false;
  
  /// Initialize the global exception handler
  void initialize() {
    if (_isInitialized) return;
    
    // Set up Flutter error callbacks
    FlutterError.onError = _handleFlutterError;
    PlatformDispatcher.instance.onError = _handlePlatformError;
    
    _isInitialized = true;
    _logger.info('ExceptionHandler', 'Global exception handler initialized');
  }

  /// Handle Flutter-specific errors (Dart exceptions in the Flutter framework)
  void _handleFlutterError(FlutterErrorDetails details) {
    // Log the error
    _logger.error(
      'FlutterError',
      'Flutter framework error: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );
    
    // In debug mode, also print to console
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  }

  /// Handle platform-level errors (native code exceptions)
  bool _handlePlatformError(Object error, StackTrace stackTrace) {
    _logger.critical(
      'PlatformError',
      'Platform-level error: $error',
      error: error,
      stackTrace: stackTrace,
    );
    
    // Return true to prevent the app from closing
    return true;
  }

  /// Wrap an async function with error handling
  Future<T?> runGuarded<T>(
    String tag,
    Future<T?> Function() action, {
    String? context,
    T? fallbackValue,
    void Function(Object, StackTrace)? onError,
  }) async {
    try {
      return await action();
    } catch (e, stackTrace) {
      final message = context != null ? 'Error in $context' : 'Error occurred';
      _logger.error(tag, message, error: e, stackTrace: stackTrace);
      
      onError?.call(e, stackTrace);
      return fallbackValue;
    }
  }

  /// Wrap a synchronous function with error handling
  T? runGuardedSync<T>(
    String tag,
    T? Function() action, {
    String? context,
    T? fallbackValue,
    void Function(Object, StackTrace)? onError,
  }) {
    try {
      return action();
    } catch (e, stackTrace) {
      final message = context != null ? 'Error in $context' : 'Error occurred';
      _logger.error(tag, message, error: e, stackTrace: stackTrace);
      
      onError?.call(e, stackTrace);
      return fallbackValue;
    }
  }
}

/// Result type for operations that can fail
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final AppException exception;
  const Failure(this.exception);
}

/// Base exception class for app-specific exceptions
class AppException implements Exception {
  final String code;
  final String message;
  final String? details;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.code,
    required this.message,
    this.details,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException($code): $message';
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException({
    super.code = 'NETWORK_ERROR',
    super.message = 'A network error occurred',
    super.details,
    super.originalError,
    super.stackTrace,
  });
}

/// Download-related exceptions
class DownloadException extends AppException {
  const DownloadException({
    super.code = 'DOWNLOAD_ERROR',
    super.message = 'A download error occurred',
    super.details,
    super.originalError,
    super.stackTrace,
  });
}

/// Authentication-related exceptions
class AuthException extends AppException {
  const AuthException({
    super.code = 'AUTH_ERROR',
    super.message = 'An authentication error occurred',
    super.details,
    super.originalError,
    super.stackTrace,
  });
}

/// Storage-related exceptions
class StorageException extends AppException {
  const StorageException({
    super.code = 'STORAGE_ERROR',
    super.message = 'A storage error occurred',
    super.details,
    super.originalError,
    super.stackTrace,
  });
}

/// Permission-related exceptions
class PermissionException extends AppException {
  const PermissionException({
    super.code = 'PERMISSION_ERROR',
    super.message = 'A permission error occurred',
    super.details,
    super.originalError,
    super.stackTrace,
  });
}

/// Extension to convert exceptions to Results
extension ResultExtension<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  
  T? get valueOrNull => switch (this) {
    Success<T>(value: final v) => v,
    Failure<T>() => null,
  };
  
  AppException? get exceptionOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(exception: final e) => e,
  };
  
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppException exception) onFailure,
  }) {
    return switch (this) {
      Success<T>(value: final v) => onSuccess(v),
      Failure<T>(exception: final e) => onFailure(e),
    };
  }
}

/// Global exception handler instance
final exceptionHandler = ExceptionHandler();
