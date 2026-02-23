import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static const String _storageKey = 'turboget_users';
  static AuthService? _instance;
  User? _currentUser;
  final List<User> _users = [];
  
  // Singleton pattern
  AuthService._();
  static AuthService get instance => _instance ??= AuthService._();

  User? get currentUser => _currentUser;
  List<User> get users => List.unmodifiable(_users);
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_storageKey);
    if (usersJson != null) {
      final usersList = jsonDecode(usersJson) as List;
      _users.addAll(
        usersList.map((json) => User.fromJson(json as Map<String, dynamic>))
      );
    }
    // Always ensure super admin exists
    if (!_users.any((u) => u.id == User.superAdmin.id)) {
      _users.add(User.superAdmin);
    }
  }

  Future<bool> login(String password) async {
    final user = _users.firstWhere(
      (u) => u.password == password,
      orElse: () => User(
        id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        password: '',
        role: UserRole.guest,
        createdAt: DateTime.now(),
      ),
    );
    _currentUser = user;
    return user.role != UserRole.guest;
  }

  Future<void> logout() async {
    _currentUser = null;
  }

  String generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final password = List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
    return password;
  }

  Future<User> createUser(String? username) async {
    if (_currentUser?.role != UserRole.superAdmin) {
      throw PlatformException(
        code: 'permission-denied',
        message: 'Only super admin can create users',
      );
    }

    final password = generatePassword();
    final user = User(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      username: username,
      password: password,
      role: UserRole.registeredUser,
      createdAt: DateTime.now(),
      createdBy: _currentUser?.id,
    );

    _users.add(user);
    await _saveUsers();
    return user;
  }

  Future<void> deleteUser(String userId) async {
    if (_currentUser?.role != UserRole.superAdmin) {
      throw PlatformException(
        code: 'permission-denied',
        message: 'Only super admin can delete users',
      );
    }

    _users.removeWhere((u) => u.id == userId && u.role != UserRole.superAdmin);
    await _saveUsers();
  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_users.map((u) => u.toJson()).toList()));
  }
}