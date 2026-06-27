/// Input validation utilities for enterprise-grade input sanitization.
///
/// This service provides comprehensive validation for:
/// - URLs
/// - Email addresses
/// - File names
/// - Passwords
/// - Usernames
class ValidationService {
  static final ValidationService _instance = ValidationService._internal();
  factory ValidationService() => _instance;
  ValidationService._internal();

  // URL validation patterns
  static final _urlPattern = RegExp(
    r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
    caseSensitive: false,
  );

  // Strict URL pattern for download URLs
  static final _strictUrlPattern = RegExp(
    r'^https?:\/\/([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
    caseSensitive: false,
  );

  // Email validation pattern
  static final _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    caseSensitive: false,
  );

  // Username validation pattern (alphanumeric and underscore, 3-20 chars)
  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  // Dangerous file name characters
  static final _dangerousCharsPattern = RegExp(r'[<>:"|?*\x00-\x1F]');

  // Path traversal patterns
  static final _pathTraversalPattern = RegExp(
    r'(\.\.%2f|\.\.%2F|%2e%2e|%2E%2E|\.\.\\|\.\.%5c|%2e%2e%5c|%2E%2E%5C)',
    caseSensitive: false,
  );

  /// Validates a URL for download
  /// Returns null if valid, error message if invalid
  String? validateUrl(String? url, {bool requireHttps = false}) {
    if (url == null || url.trim().isEmpty) {
      return 'URL is required';
    }

    final trimmed = url.trim();

    if (trimmed.length > 2048) {
      return 'URL is too long (max 2048 characters)';
    }

    if (requireHttps && !trimmed.startsWith('https://')) {
      return 'HTTPS is required for secure downloads';
    }

    if (!_strictUrlPattern.hasMatch(trimmed)) {
      return 'Invalid URL format';
    }

    // Check for path traversal attempts
    if (_pathTraversalPattern.hasMatch(trimmed.toLowerCase())) {
      return 'URL contains invalid characters';
    }

    // Block potentially dangerous schemes
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme.isNotEmpty) {
      if (!['http', 'https'].contains(uri.scheme.toLowerCase())) {
        return 'Only HTTP and HTTPS URLs are allowed';
      }
    }

    return null;
  }

  /// Validates a username
  /// Returns null if valid, error message if invalid
  String? validateUsername(String? username) {
    if (username == null || username.trim().isEmpty) {
      return 'Username is required';
    }

    final trimmed = username.trim();

    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters';
    }

    if (trimmed.length > 20) {
      return 'Username must be at most 20 characters';
    }

    if (!_usernamePattern.hasMatch(trimmed)) {
      return 'Username can only contain letters, numbers, and underscores';
    }

    // Check for reserved names
    final reservedNames = ['admin', 'root', 'super', 'system', 'moderator'];
    if (reservedNames.contains(trimmed.toLowerCase())) {
      return 'This username is reserved';
    }

    return null;
  }

  /// Validates a password
  /// Returns null if valid, error message if invalid
  String? validatePassword(String? password, {
    int minLength = 8,
    bool requireUppercase = true,
    bool requireLowercase = true,
    bool requireDigit = true,
    bool requireSpecial = true,
  }) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < minLength) {
      return 'Password must be at least $minLength characters';
    }

    if (password.length > 128) {
      return 'Password is too long (max 128 characters)';
    }

    if (requireUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (requireLowercase && !password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (requireDigit && !password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one digit';
    }

    if (requireSpecial && !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  /// Validates a file name
  /// Returns null if valid, error message if invalid
  String? validateFileName(String? fileName) {
    if (fileName == null || fileName.trim().isEmpty) {
      return 'File name is required';
    }

    final trimmed = fileName.trim();

    if (trimmed.length > 255) {
      return 'File name is too long (max 255 characters)';
    }

    if (_dangerousCharsPattern.hasMatch(trimmed)) {
      return 'File name contains invalid characters';
    }

    // Check for reserved names
    final reservedNames = [
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
    ];
    if (reservedNames.contains(trimmed.toUpperCase().split('.').first)) {
      return 'This file name is reserved';
    }

    return null;
  }

  /// Sanitizes a file name for safe storage
  String sanitizeFileName(String fileName) {
    // Remove dangerous characters
    var sanitized = fileName.replaceAll(_dangerousCharsPattern, '_');
    
    // Replace path separators
    sanitized = sanitized.replaceAll(RegExp(r'[/\\]'), '_');
    
    // Remove leading/trailing dots and spaces
    sanitized = sanitized.trim();
    sanitized = sanitized.replaceAll(RegExp(r'^\.+'), '');
    
    // Limit length
    if (sanitized.length > 255) {
      final extension = sanitized.split('.').last;
      final nameWithoutExt = sanitized.substring(0, 255 - extension.length - 1);
      sanitized = '$nameWithoutExt.$extension';
    }
    
    // Ensure not empty
    if (sanitized.isEmpty) {
      sanitized = 'unnamed_file';
    }
    
    return sanitized;
  }

  /// Sanitizes a URL for logging/display (removes sensitive params)
  String sanitizeUrlForLogging(String url) {
    try {
      final uri = Uri.parse(url);
      final params = uri.queryParameters;
      
      // List of potentially sensitive parameter names
      const sensitiveParams = ['token', 'key', 'secret', 'password', 'auth', 'api_key', 'apikey'];
      
      if (params.keys.any((k) => sensitiveParams.contains(k.toLowerCase()))) {
        final sanitizedParams = Map<String, String>.from(params);
        for (final key in sensitiveParams) {
          if (sanitizedParams.containsKey(key)) {
            sanitizedParams[key] = '***REDACTED***';
          }
        }
        
        return uri.replace(
          queryParameters: sanitizedParams,
        ).toString();
      }
      
      return url;
    } catch (_) {
      return '[REDACTED URL]';
    }
  }

  /// Validates email address
  /// Returns null if valid, error message if invalid
  String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Email is required';
    }

    final trimmed = email.trim();

    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Invalid email format';
    }

    if (trimmed.length > 254) {
      return 'Email is too long';
    }

    return null;
  }

  /// Calculates password strength (0-100)
  int calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    
    int score = 0;
    
    // Length scoring
    if (password.length >= 8) score += 20;
    if (password.length >= 12) score += 10;
    if (password.length >= 16) score += 10;
    
    // Character variety scoring
    if (password.contains(RegExp(r'[a-z]'))) score += 10;
    if (password.contains(RegExp(r'[A-Z]'))) score += 10;
    if (password.contains(RegExp(r'[0-9]'))) score += 10;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score += 15;
    
    // Bonus for mixing character types
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    final typeCount = [hasLower, hasUpper, hasDigit, hasSpecial].where((x) => x).length;
    if (typeCount >= 3) score += 10;
    if (typeCount == 4) score += 5;
    
    return score.clamp(0, 100);
  }

  /// Returns password strength label
  String getPasswordStrengthLabel(int strength) {
    if (strength < 30) return 'Weak';
    if (strength < 50) return 'Fair';
    if (strength < 70) return 'Good';
    if (strength < 90) return 'Strong';
    return 'Very Strong';
  }
}

/// Global validation service instance
final validationService = ValidationService();
