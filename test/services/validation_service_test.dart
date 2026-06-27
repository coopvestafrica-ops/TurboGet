import 'package:flutter_test/flutter_test.dart';
import 'package:turboget/services/validation_service.dart';

void main() {
  late ValidationService validationService;

  setUp(() {
    validationService = ValidationService();
  });

  group('URL Validation', () {
    test('should accept valid HTTP URL', () {
      expect(
        validationService.validateUrl('https://example.com/file.mp4'),
        isNull,
      );
    });

    test('should accept valid HTTP URL without https', () {
      expect(
        validationService.validateUrl('http://example.com/file.mp4'),
        isNull,
      );
    });

    test('should reject empty URL', () {
      expect(
        validationService.validateUrl(''),
        equals('URL is required'),
      );
    });

    test('should reject null URL', () {
      expect(
        validationService.validateUrl(null),
        equals('URL is required'),
      );
    });

    test('should reject URL with path traversal', () {
      expect(
        validationService.validateUrl('https://example.com/../etc/passwd'),
        equals('URL contains invalid characters'),
      );
    });

    test('should reject non-HTTP schemes', () {
      expect(
        validationService.validateUrl('file:///etc/passwd'),
        equals('Only HTTP and HTTPS URLs are allowed'),
      );
    });

    test('should require HTTPS when specified', () {
      expect(
        validationService.validateUrl('http://example.com/file.mp4', requireHttps: true),
        equals('HTTPS is required for secure downloads'),
      );
    });

    test('should reject overly long URLs', () {
      final longUrl = 'https://example.com/${'a' * 3000}';
      expect(
        validationService.validateUrl(longUrl),
        equals('URL is too long (max 2048 characters)'),
      );
    });
  });

  group('Username Validation', () {
    test('should accept valid username', () {
      expect(
        validationService.validateUsername('john_doe'),
        isNull,
      );
    });

    test('should reject empty username', () {
      expect(
        validationService.validateUsername(''),
        equals('Username is required'),
      );
    });

    test('should reject username shorter than 3 characters', () {
      expect(
        validationService.validateUsername('ab'),
        equals('Username must be at least 3 characters'),
      );
    });

    test('should reject username longer than 20 characters', () {
      expect(
        validationService.validateUsername('a' * 21),
        equals('Username must be at least 3 characters'),
      );
    });

    test('should reject username with special characters', () {
      expect(
        validationService.validateUsername('john@doe'),
        equals('Username can only contain letters, numbers, and underscores'),
      );
    });

    test('should reject reserved usernames', () {
      expect(
        validationService.validateUsername('admin'),
        equals('This username is reserved'),
      );
      expect(
        validationService.validateUsername('root'),
        equals('This username is reserved'),
      );
    });
  });

  group('Password Validation', () {
    test('should accept strong password', () {
      expect(
        validationService.validatePassword('SecureP@ss123'),
        isNull,
      );
    });

    test('should reject empty password', () {
      expect(
        validationService.validatePassword(''),
        equals('Password is required'),
      );
    });

    test('should reject short password', () {
      expect(
        validationService.validatePassword('Short1!'),
        equals('Password must be at least 8 characters'),
      );
    });

    test('should reject password without uppercase', () {
      expect(
        validationService.validatePassword('lowercase123!', requireUppercase: true),
        equals('Password must contain at least one uppercase letter'),
      );
    });

    test('should reject password without lowercase', () {
      expect(
        validationService.validatePassword('UPPERCASE123!', requireLowercase: true),
        equals('Password must contain at least one lowercase letter'),
      );
    });

    test('should reject password without digit', () {
      expect(
        validationService.validatePassword('NoDigits!@#', requireDigit: true),
        equals('Password must contain at least one digit'),
      );
    });

    test('should reject password without special character', () {
      expect(
        validationService.validatePassword('NoSpecialChar123', requireSpecial: true),
        equals('Password must contain at least one special character'),
      );
    });
  });

  group('File Name Validation', () {
    test('should accept valid file name', () {
      expect(
        validationService.validateFileName('document.pdf'),
        isNull,
      );
    });

    test('should reject empty file name', () {
      expect(
        validationService.validateFileName(''),
        equals('File name is required'),
      );
    });

    test('should reject file name with dangerous characters', () {
      expect(
        validationService.validateFileName('file<name>.txt'),
        equals('File name contains invalid characters'),
      );
    });

    test('should reject reserved file names', () {
      expect(
        validationService.validateFileName('CON.txt'),
        equals('This file name is reserved'),
      );
      expect(
        validationService.validateFileName('PRN.mp4'),
        equals('This file name is reserved'),
      );
    });
  });

  group('File Name Sanitization', () {
    test('should remove dangerous characters', () {
      expect(
        validationService.sanitizeFileName('file<name>.txt'),
        equals('file_name_.txt'),
      );
    });

    test('should replace path separators', () {
      expect(
        validationService.sanitizeFileName('path/to/file.txt'),
        equals('path_to_file.txt'),
      );
    });

    test('should trim leading/trailing spaces', () {
      expect(
        validationService.sanitizeFileName('  file.txt  '),
        equals('file.txt'),
      );
    });

    test('should handle empty input', () {
      expect(
        validationService.sanitizeFileName(''),
        equals('unnamed_file'),
      );
    });

    test('should truncate very long file names', () {
      final longName = '${'a' * 300}.txt';
      expect(
        validationService.sanitizeFileName(longName).length,
        lessThanOrEqualTo(255),
      );
    });
  });

  group('URL Sanitization for Logging', () {
    test('should redact sensitive parameters', () {
      final url = 'https://api.example.com/download?token=secret123';
      final sanitized = validationService.sanitizeUrlForLogging(url);
      
      expect(sanitized.contains('secret123'), isFalse);
      expect(sanitized.contains('***REDACTED***'), isTrue);
    });

    test('should keep non-sensitive URLs unchanged', () {
      final url = 'https://example.com/file.mp4';
      final sanitized = validationService.sanitizeUrlForLogging(url);
      
      expect(sanitized, equals(url));
    });
  });

  group('Password Strength', () {
    test('should calculate weak password strength', () {
      expect(
        validationService.calculatePasswordStrength('abc'),
        lessThan(30),
      );
    });

    test('should calculate strong password strength', () {
      expect(
        validationService.calculatePasswordStrength('Str0ng!P@ssw0rd'),
        greaterThanOrEqualTo(70),
      );
    });

    test('should return strength labels correctly', () {
      expect(validationService.getPasswordStrengthLabel(20), equals('Weak'));
      expect(validationService.getPasswordStrengthLabel(40), equals('Fair'));
      expect(validationService.getPasswordStrengthLabel(60), equals('Good'));
      expect(validationService.getPasswordStrengthLabel(80), equals('Strong'));
      expect(validationService.getPasswordStrengthLabel(100), equals('Very Strong'));
    });
  });

  group('Email Validation', () {
    test('should accept valid email', () {
      expect(
        validationService.validateEmail('user@example.com'),
        isNull,
      );
    });

    test('should reject invalid email', () {
      expect(
        validationService.validateEmail('notanemail'),
        equals('Invalid email format'),
      );
    });

    test('should reject empty email', () {
      expect(
        validationService.validateEmail(''),
        equals('Email is required'),
      );
    });
  });
}
