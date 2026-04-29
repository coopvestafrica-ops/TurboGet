import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

/// Authentication and user management.
///
/// The first time the app runs, no users exist — the UI should show a
/// first-run setup screen that calls [createSuperAdmin] to create the
/// admin account. Super-admins may then call [createUser] to create
/// registered users. Guests are created implicitly when [loginAsGuest]
/// is called; guests see ads but registered users do not.
class AuthService {
  static const String _usersKey = 'turboget_users_v2';
  static const String _currentUserKey = 'turboget_current_user_id';

  static AuthService? _instance;
  AuthService._();
  static AuthService get instance => _instance ??= AuthService._();

  final List<User> _users = [];
  User? _currentUser;

  User? get currentUser => _currentUser;
  List<User> get users => List.unmodifiable(_users);
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isRegistered =>
      _currentUser != null && _currentUser!.role != UserRole.guest;

  /// Whether the first-run setup flow is required (no super-admin yet).
  bool get needsInitialSetup =>
      !_users.any((u) => u.role == UserRole.superAdmin);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_usersKey);
    _users.clear();
    if (json != null) {
      final list = jsonDecode(json) as List;
      _users.addAll(
        list.map((e) => User.fromJson(e as Map<String, dynamic>)),
      );
    }

    final id = prefs.getString(_currentUserKey);
    if (id != null) {
      _currentUser = _users.firstWhere(
        (u) => u.id == id,
        orElse: () => _guest(),
      );
      if (_currentUser!.role == UserRole.guest) {
        await prefs.remove(_currentUserKey);
        _currentUser = null;
      }
    }
  }

  /// Creates the first super-admin account. Called from the first-run
  /// setup screen. Throws if a super-admin already exists.
  ///
  /// Returns the created admin and the plain-text recovery code so the
  /// UI can show it once. The recovery code is **not** retrievable
  /// later — it's stored only as a salted hash.
  Future<({User user, String recoveryCode})> createSuperAdmin({
    required String username,
    required String password,
  }) async {
    if (!needsInitialSetup) {
      throw StateError('Super admin already configured');
    }
    _validatePassword(password);
    final salt = _randomSalt();
    final recoveryCode = _generateRecoveryCode();
    final recoverySalt = _randomSalt();
    final admin = User(
      id: 'super_admin',
      username: username.trim(),
      passwordHash: User.hashPassword(password, salt),
      passwordSalt: salt,
      role: UserRole.superAdmin,
      createdAt: DateTime.now(),
      recoveryHash: User.hashPassword(recoveryCode, recoverySalt),
      recoverySalt: recoverySalt,
    );
    _users.add(admin);
    _currentUser = admin;
    await _saveUsers();
    await _saveCurrentUser();
    return (user: admin, recoveryCode: recoveryCode);
  }

  /// Resets the super-admin password using a previously issued
  /// recovery code. Returns `true` on success.
  Future<bool> resetSuperAdminPasswordWithRecoveryCode({
    required String recoveryCode,
    required String newPassword,
  }) async {
    _validatePassword(newPassword);
    final adminIdx = _users.indexWhere(
      (u) => u.role == UserRole.superAdmin,
    );
    if (adminIdx == -1) return false;
    final admin = _users[adminIdx];
    if (!admin.verifyRecoveryCode(recoveryCode)) return false;
    final salt = _randomSalt();
    final newRecoveryCode = _generateRecoveryCode();
    final newRecoverySalt = _randomSalt();
    _users[adminIdx] = admin.copyWith(
      passwordHash: User.hashPassword(newPassword, salt),
      passwordSalt: salt,
      // Issue a new recovery code so the previous one can't be reused.
      recoveryHash: User.hashPassword(newRecoveryCode, newRecoverySalt),
      recoverySalt: newRecoverySalt,
    );
    _lastIssuedRecoveryCode = newRecoveryCode;
    if (_currentUser?.id == admin.id) _currentUser = _users[adminIdx];
    await _saveUsers();
    return true;
  }

  /// The most recently issued recovery code from
  /// [resetSuperAdminPasswordWithRecoveryCode]. Cleared after read.
  String? takeLastIssuedRecoveryCode() {
    final code = _lastIssuedRecoveryCode;
    _lastIssuedRecoveryCode = null;
    return code;
  }

  String? _lastIssuedRecoveryCode;

  /// Logs in a user by `username` + `password`. Returns the authenticated
  /// [User] or `null` if credentials are invalid.
  Future<User?> login(String username, String password) async {
    final normalized = username.trim();
    if (normalized.isEmpty || password.isEmpty) return null;

    for (final u in _users) {
      if (u.role == UserRole.guest) continue;
      if ((u.username ?? '').toLowerCase() != normalized.toLowerCase()) {
        continue;
      }
      if (u.verifyPassword(password)) {
        _currentUser = u;
        await _saveCurrentUser();
        return u;
      }
    }
    return null;
  }

  /// Signs the current session in as a transient guest (no persistence).
  /// Guests see ads and cannot manage users.
  Future<User> loginAsGuest() async {
    final guest = _guest();
    _currentUser = guest;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    return guest;
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  /// Creates a new registered user. Only callable by the super-admin.
  /// Returns the created user and its generated plain-text password so
  /// the UI can display it once.
  Future<({User user, String password})> createUser({
    required String username,
  }) async {
    if (_currentUser?.role != UserRole.superAdmin) {
      throw PlatformException(
        code: 'permission-denied',
        message: 'Only the super admin can create users',
      );
    }
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Username cannot be empty');
    }
    if (_users.any(
      (u) => (u.username ?? '').toLowerCase() == trimmed.toLowerCase(),
    )) {
      throw StateError('Username "$trimmed" already exists');
    }

    final plain = _generatePassword();
    final salt = _randomSalt();
    final user = User(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      username: trimmed,
      passwordHash: User.hashPassword(plain, salt),
      passwordSalt: salt,
      role: UserRole.registeredUser,
      createdAt: DateTime.now(),
      createdBy: _currentUser?.id,
    );
    _users.add(user);
    await _saveUsers();
    return (user: user, password: plain);
  }

  Future<void> deleteUser(String userId) async {
    if (_currentUser?.role != UserRole.superAdmin) {
      throw PlatformException(
        code: 'permission-denied',
        message: 'Only the super admin can delete users',
      );
    }
    _users.removeWhere(
      (u) => u.id == userId && u.role != UserRole.superAdmin,
    );
    await _saveUsers();
  }

  /// Rotates the super-admin password.
  Future<void> changeSuperAdminPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final admin = _users.firstWhere(
      (u) => u.role == UserRole.superAdmin,
      orElse: () => throw StateError('No super admin configured'),
    );
    if (!admin.verifyPassword(oldPassword)) {
      throw ArgumentError('Current password is incorrect');
    }
    _validatePassword(newPassword);
    final salt = _randomSalt();
    final updated = admin.copyWith(
      passwordHash: User.hashPassword(newPassword, salt),
      passwordSalt: salt,
    );
    final idx = _users.indexWhere((u) => u.id == admin.id);
    _users[idx] = updated;
    if (_currentUser?.id == admin.id) _currentUser = updated;
    await _saveUsers();
  }

  // ---------------------------------------------------------------------
  // Internals

  User _guest() => User(
        id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        passwordHash: '',
        passwordSalt: '',
        role: UserRole.guest,
        createdAt: DateTime.now(),
      );

  void _validatePassword(String password) {
    if (password.length < 6) {
      throw ArgumentError('Password must be at least 6 characters');
    }
  }

  String _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Generates a human-friendly recovery code, formatted as four
  /// 4-character groups separated by dashes (e.g. `7K2P-9MX4-Q3RT-LZ8N`).
  /// Uses an alphabet without easily confused characters.
  String _generateRecoveryCode() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final rng = Random.secure();
    final groups = <String>[];
    for (var g = 0; g < 4; g++) {
      groups.add(
        List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join(),
      );
    }
    return groups.join('-');
  }

  String _randomSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final persisted = _users
        .where((u) => u.role != UserRole.guest)
        .map((u) => u.toJson())
        .toList();
    await prefs.setString(_usersKey, jsonEncode(persisted));
  }

  Future<void> _saveCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _currentUser;
    if (user == null || user.role == UserRole.guest) {
      await prefs.remove(_currentUserKey);
    } else {
      await prefs.setString(_currentUserKey, user.id);
    }
  }
}
