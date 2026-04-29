import 'dart:convert';
import 'package:crypto/crypto.dart';

enum UserRole {
  superAdmin,
  registeredUser,
  guest,
}

/// Represents an authenticated user of the app.
///
/// Passwords are stored as a SHA-256 hash with a per-user salt; the raw
/// password is only ever held transiently during login/creation.
class User {
  final String id;
  final String? username;

  /// SHA-256 hash of `salt + password`, hex-encoded.
  final String passwordHash;

  /// Random per-user salt, hex-encoded.
  final String passwordSalt;

  final UserRole role;
  final DateTime createdAt;
  final String? createdBy;

  /// SHA-256 hash of `recoverySalt + recoveryCode`, hex-encoded. Only
  /// set on the super-admin and used by the forgot-password flow.
  final String? recoveryHash;

  /// Salt for [recoveryHash], hex-encoded.
  final String? recoverySalt;

  const User({
    required this.id,
    this.username,
    required this.passwordHash,
    required this.passwordSalt,
    required this.role,
    required this.createdAt,
    this.createdBy,
    this.recoveryHash,
    this.recoverySalt,
  });

  bool get isAdmin => role == UserRole.superAdmin;
  bool get isGuest => role == UserRole.guest;
  bool get shouldShowAds => role == UserRole.guest;

  /// Returns `true` if [password] matches this user's stored hash.
  bool verifyPassword(String password) {
    final computed = hashPassword(password, passwordSalt);
    return computed == passwordHash;
  }

  /// Hashes `password` with `salt` using SHA-256.
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// Returns `true` if [code] matches this user's recovery hash.
  bool verifyRecoveryCode(String code) {
    final salt = recoverySalt;
    final hash = recoveryHash;
    if (salt == null || hash == null) return false;
    return hashPassword(code.trim().toUpperCase(), salt) == hash;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'recoveryHash': recoveryHash,
        'recoverySalt': recoverySalt,
      };

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String?,
      passwordHash: json['passwordHash'] as String? ?? '',
      passwordSalt: json['passwordSalt'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.guest,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      createdBy: json['createdBy'] as String?,
      recoveryHash: json['recoveryHash'] as String?,
      recoverySalt: json['recoverySalt'] as String?,
    );
  }

  User copyWith({
    String? username,
    String? passwordHash,
    String? passwordSalt,
    UserRole? role,
    String? recoveryHash,
    String? recoverySalt,
  }) {
    return User(
      id: id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      role: role ?? this.role,
      createdAt: createdAt,
      createdBy: createdBy,
      recoveryHash: recoveryHash ?? this.recoveryHash,
      recoverySalt: recoverySalt ?? this.recoverySalt,
    );
  }
}
