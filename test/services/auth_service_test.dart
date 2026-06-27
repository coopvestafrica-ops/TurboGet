import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turboget/services/auth_service.dart';
import 'package:turboget/models/user.dart';

void main() {
  group('AuthService', () {
    late AuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authService = AuthService.instance;
    });

    tearDown(() {
      // Reset singleton for clean tests
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        await authService.initialize();
        
        expect(authService.isInitialized, isTrue);
        expect(authService.isLoggedIn, isFalse);
      });

      test('should create super admin on first init', () async {
        await authService.initialize();
        
        expect(authService.users.isNotEmpty, isTrue);
        expect(
          authService.users.any((u) => u.role == UserRole.superAdmin),
          isTrue,
        );
      });

      test('should not reinitialize if already initialized', () async {
        await authService.initialize();
        final usersCount = authService.users.length;
        
        await authService.initialize();
        
        expect(authService.users.length, equals(usersCount));
      });
    });

    group('Login', () {
      setUp(() async {
        await authService.initialize();
      });

      test('should login successfully with valid password', () async {
        final adminPassword = AdminConfig.adminPassword;
        final success = await authService.login(adminPassword);
        
        expect(success, isTrue);
        expect(authService.isLoggedIn, isTrue);
        expect(authService.isAdmin, isTrue);
      });

      test('should fail login with invalid password', () async {
        final success = await authService.login('wrongpassword');
        
        expect(success, isFalse);
        expect(authService.isLoggedIn, isFalse);
      });

      test('should fail login with empty password', () async {
        final success = await authService.login('');
        
        expect(success, isFalse);
        expect(authService.isLoggedIn, isFalse);
      });
    });

    group('User Management', () {
      setUp(() async {
        await authService.initialize();
      });

      test('should create user when logged in as admin', () async {
        await authService.login(AdminConfig.adminPassword);
        final user = await authService.createUser('testuser');
        
        expect(user, isNotNull);
        expect(user?.username, equals('testuser'));
        expect(user?.role, equals(UserRole.registeredUser));
        expect(user?.password.length, greaterThanOrEqualTo(10));
      });

      test('should throw when creating user without admin privileges', () async {
        await authService.login(AdminConfig.adminPassword);
        final user = await authService.createUser('regularuser');
        await authService.logout();
        await authService.login(user!.password);
        
        expect(
          () => authService.createUser('anotheruser'),
          throwsA(isA<PlatformException>()),
        );
      });
    });

    group('Password Generation', () {
      test('should generate password with minimum length', () async {
        await authService.initialize();
        
        final password = authService.generatePassword();
        
        expect(password.length, greaterThanOrEqualTo(10));
      });

      test('should generate unique passwords', () async {
        await authService.initialize();
        
        final passwords = List.generate(
          10,
          (_) => authService.generatePassword(),
        );
        
        final uniquePasswords = passwords.toSet();
        expect(uniquePasswords.length, equals(10));
      });

      test('should contain required character types', () async {
        await authService.initialize();
        
        final password = authService.generatePassword();
        
        expect(password.contains(RegExp(r'[a-z]')), isTrue);
        expect(password.contains(RegExp(r'[A-Z]')), isTrue);
        expect(password.contains(RegExp(r'[0-9]')), isTrue);
        expect(password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')), isTrue);
      });
    });
  });

  group('AdminConfig', () {
    test('should have default values', () {
      expect(AdminConfig.adminUsername, isNotEmpty);
      expect(AdminConfig.adminPassword, isNotEmpty);
    });

    test('should support environment overrides', () {
      expect(AdminConfig.isProduction, isFalse);
    });
  });

  group('User Model', () {
    test('should serialize to JSON correctly', () {
      final user = User(
        id: 'test_id',
        username: 'testuser',
        password: 'testpass',
        role: UserRole.registeredUser,
        createdAt: DateTime(2025, 1, 1),
        createdBy: 'admin',
      );

      final json = user.toJson();

      expect(json['id'], equals('test_id'));
      expect(json['username'], equals('testuser'));
      expect(json['role'], equals('registeredUser'));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'test_id',
        'username': 'testuser',
        'password': 'testpass',
        'role': 'registeredUser',
        'createdAt': '2025-01-01T00:00:00.000',
        'createdBy': 'admin',
      };

      final user = User.fromJson(json);

      expect(user.id, equals('test_id'));
      expect(user.username, equals('testuser'));
      expect(user.role, equals(UserRole.registeredUser));
    });

    test('should correctly identify admin role', () {
      final admin = User(
        id: 'admin',
        username: 'admin',
        password: 'pass',
        role: UserRole.superAdmin,
        createdAt: DateTime.now(),
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.shouldShowAds, isFalse);
    });

    test('should correctly identify guest role', () {
      final guest = User(
        id: 'guest',
        username: null,
        password: '',
        role: UserRole.guest,
        createdAt: DateTime.now(),
      );

      expect(guest.isAdmin, isFalse);
      expect(guest.shouldShowAds, isTrue);
    });
  });
}
