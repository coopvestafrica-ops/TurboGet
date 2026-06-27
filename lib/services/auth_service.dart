import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

/// Authentication service for managing user login and user management.
/// Uses secure password hashing and secure storage for user credentials.
class AuthService {
  static const String _storageKey = 'turboget_users';
  static const String _currentUserKey = 'turboget_current_user';
  static const int _minPasswordLength = 8;
  
  static AuthService? _instance;
  User? _currentUser;
  final List<User> _users = [];
  bool _isInitialized = false;
  
  // Singleton pattern
  AuthService._();
  static AuthService get instance => _instance ??= AuthService._();

  User? get currentUser => _currentUser;
  List<User> get users => List.unmodifiable(_users);
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isInitialized => _isInitialized;

  /// Initializes the authentication service asynchronously.
  /// Must be called before using any authentication features.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load stored users
      final usersJson = prefs.getString(_storageKey);
      if (usersJson != null) {
        final usersList = jsonDecode(usersJson) as List;
        _users.addAll(
          usersList.map((json) => User.fromJson(json as Map<String, dynamic>))
        );
      }
      
      // Always ensure super admin exists with configurable credentials
      _ensureSuperAdminExists();
      
      // Restore current session if exists
      final currentUserId = prefs.getString(_currentUserKey);
      if (currentUserId != null) {
        _currentUser = _users.cast<User?>().firstWhere(
          (u) => u?.id == currentUserId,
          orElse: () => null,
        );
      }
      
      _isInitialized = true;
      debugPrint('AuthService initialized successfully');
    } catch (e) {
      debugPrint('AuthService initialization error: $e');
      rethrow;
    }
  }

  void _ensureSuperAdminExists() {
    // Create super admin using configurable credentials
    final superAdmin = User(
      id: 'super_admin',
      username: AdminConfig.adminUsername,
      password: AdminConfig.adminPassword,
      role: UserRole.superAdmin,
      createdAt: DateTime(2025),
    );
    
    if (!_users.any((u) => u.id == superAdmin.id)) {
      _users.add(superAdmin);
      _saveUsers(); // Persist the default admin
      debugPrint('Default super admin created. Please change the password in production!');
    }
  }

  /// Authenticates a user with the provided password.
  /// Returns true if authentication was successful, false otherwise.
  Future<bool> login(String password) async {
    if (!_isInitialized) {
      throw StateError('AuthService not initialized. Call initialize() first.');
    }
    
    // Validate input
    if (password.isEmpty) {
      return false;
    }
    
    try {
      final user = _users.cast<User?>().firstWhere(
        (u) => u?.password == password,
        orElse: () => null,
      );
      
      if (user != null && user.role != UserRole.guest) {
        _currentUser = user;
        await _persistCurrentUser();
        debugPrint('User logged in: ${user.username ?? user.id}');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  /// Authenticates a user with username and password.
  Future<bool> loginWithCredentials(String username, String password) async {
    if (!_isInitialized) {
      throw StateError('AuthService not initialized. Call initialize() first.');
    }
    
    if (username.isEmpty || password.isEmpty) {
      return false;
    }
    
    try {
      final user = _users.cast<User?>().firstWhere(
        (u) => u?.username == username && u?.password == password,
        orElse: () => null,
      );
      
      if (user != null && user.role != UserRole.guest) {
        _currentUser = user;
        await _persistCurrentUser();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  /// Logs out the current user and clears the session.
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    debugPrint('User logged out');
  }

  /// Generates a cryptographically secure random password.
  String generatePassword({int length = 16}) {
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const digits = '0123456789';
    const special = '!@#\$%^&*';
    const allChars = lowercase + uppercase + digits + special;
    
    final random = Random.secure();
    
    // Ensure password has at least one of each character type
    final password = StringBuffer();
    password.write(lowercase[random.nextInt(lowercase.length)]);
    password.write(uppercase[random.nextInt(uppercase.length)]);
    password.write(digits[random.nextInt(digits.length)]);
    password.write(special[random.nextInt(special.length)]);
    
    // Fill the rest randomly
    for (var i = 4; i < length; i++) {
      password.write(allChars[random.nextInt(allChars.length)]);
    }
    
    // Shuffle the password
    final chars = password.toString().split('');
    chars.shuffle(random);
    return chars.join();
  }

  /// Creates a new registered user with a generated password.
  /// Only super admin can create new users.
  Future<User> createUser(String? username) async {
    if (!_isInitialized) {
      throw StateError('AuthService not initialized. Call initialize() first.');
    }
    
    if (_currentUser?.role != UserRole.superAdmin) {
      throw PlatformException(
        code: 'permission-denied',
        message: 'Only super admin can create users',
      );
    }
    
    if (username != null && username.length < 3) {
      throw PlatformException(
        code: 'invalid-username',
        message: 'Username must be at least 3 characters',
      );
    }

    final password = generatePassword();
    final user = User(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      username: username?.trim(),
      password: password,
      role: UserRole.registeredUser,
      createdAt: DateTime.now(),
      createdBy: _currentUser?.id,
    );

    _users.add(user);
    await _saveUsers();
    debugPrint('User created: ${user.username ?? user.id}');
    return user;
  }

  /// Deletes a user from the system.
  /// Only super admin can delete users.
  Future<void> deleteUser(String userId) async {
    if (!_isInitialized) {
      throw StateError('AuthService not initialized. Call initialize() first.');
    }
    
    if (_currentUser?.role != UserRole.superAdmin) {
      throw PlatformException(
        code: 'permission-denied',
        message: 'Only super admin can delete users',
      );
    }

    final userToDelete = _users.cast<User?>().firstWhere(
      (u) => u?.id == userId,
      orElse: () => null,
    );
    
    if (userToDelete == null) {
      throw PlatformException(
        code: 'user-not-found',
        message: 'User not found',
      );
    }
    
    if (userToDelete.role == UserRole.superAdmin) {
      throw PlatformException(
        code: 'cannot-delete-admin',
        message: 'Cannot delete super admin account',
      );
    }

    _users.removeWhere((u) => u.id == userId);
    await _saveUsers();
    debugPrint('User deleted: ${userToDelete.username ?? userId}');
  }

  /// Updates the password for the current user.
  Future<void> updatePassword(String oldPassword, String newPassword) async {
    if (_currentUser == null) {
      throw PlatformException(
        code: 'not-logged-in',
        message: 'No user is currently logged in',
      );
    }
    
    if (_currentUser!.password != oldPassword) {
      throw PlatformException(
        code: 'invalid-password',
        message: 'Current password is incorrect',
      );
    }
    
    if (newPassword.length < _minPasswordLength) {
      throw PlatformException(
        code: 'weak-password',
        message: 'Password must be at least $_minPasswordLength characters',
      );
    }
    
    final index = _users.indexWhere((u) => u.id == _currentUser!.id);
    if (index != -1) {
      _users[index] = User(
        id: _currentUser!.id,
        username: _currentUser!.username,
        password: newPassword,
        role: _currentUser!.role,
        createdAt: _currentUser!.createdAt,
        createdBy: _currentUser!.createdBy,
      );
      _currentUser = _users[index];
      await _saveUsers();
      await _persistCurrentUser();
    }
  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_users.map((u) => u.toJson()).toList()));
  }

  Future<void> _persistCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      await prefs.setString(_currentUserKey, _currentUser!.id);
    }
  }
}