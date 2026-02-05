// ==============================================================================
// CEMPPSA Field App - Modelo User & Auth
// ==============================================================================

enum UserRole {
  user,
  supervisor,
  admin;

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'supervisor':
        return UserRole.supervisor;
      default:
        return UserRole.user;
    }
  }
}

class User {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.role = UserRole.user,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['name'] ?? '',
      role: UserRole.fromString(json['role']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
    };
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isSupervisor => role == UserRole.supervisor || role == UserRole.admin;
}

class AuthResponse {
  final String accessToken;
  final String? refreshToken;
  final User user;

  AuthResponse({
    required this.accessToken,
    this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
