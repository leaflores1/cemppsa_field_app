class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final String? role;
  final String? platformAccess;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.role,
    this.platformAccess,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final email = (json['email'] ?? '').toString().trim();
    final rawDisplay = (json['display_name'] ?? '').toString().trim();
    return AuthUser(
      id: (json['id'] ?? '').toString().trim(),
      email: email,
      displayName: rawDisplay.isNotEmpty ? rawDisplay : email,
      role: json['role']?.toString(),
      platformAccess: json['platform_access']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'role': role,
      'platform_access': platformAccess,
    };
  }
}

class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final AuthUser user;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return AuthSession(
      accessToken: (json['access_token'] ?? '').toString().trim(),
      refreshToken: (json['refresh_token'] ?? '').toString().trim(),
      tokenType: (json['token_type'] ?? 'bearer').toString().trim(),
      user: AuthUser.fromJson(
        userJson is Map ? _toStringDynamicMap(userJson) : const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'user': user.toJson(),
    };
  }

  static Map<String, dynamic> _toStringDynamicMap(Map raw) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
}
