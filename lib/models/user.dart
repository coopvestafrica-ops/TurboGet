enum UserRole {
  superAdmin,
  registeredUser,
  guest
}

class User {
  final String id;
  final String? username;
  final String password;
  final UserRole role;
  final DateTime createdAt;
  final String? createdBy;

  const User({
    required this.id,
    this.username,
    required this.password,
    required this.role,
    required this.createdAt,
    this.createdBy,
  });

  bool get isAdmin => role == UserRole.superAdmin;
  bool get shouldShowAds => role == UserRole.guest;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'role': role.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      password: json['password'],
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${json['role']}',
        orElse: () => UserRole.guest,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      createdBy: json['createdBy'],
    );
  }

  static User get superAdmin => User(
    id: 'super_admin',
    username: 'Teejayfpi',
    password: 'Temiloluwa@1963',
    role: UserRole.superAdmin,
    createdAt: DateTime(2025),
  );
}