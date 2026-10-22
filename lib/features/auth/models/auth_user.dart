class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.role = 'customer',
  });

  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];

    final Map<String, dynamic> data;
    if (rawUser is Map<String, dynamic>) {
      data = rawUser;
    } else if (rawUser is Map) {
      data = Map<String, dynamic>.from(rawUser);
    } else {
      data = json;
    }

    return AuthUser(
      id: (data['id'] ?? '').toString(),
      fullName: (data['full_name'] ?? data['name'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      email: data['email']?.toString(),
      role: (data['role'] ?? 'customer').toString(),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    this.refreshToken,
  });

  final AuthUser user;
  final String accessToken;
  final String? refreshToken;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final userJson = rawUser is Map ? Map<String, dynamic>.from(rawUser) : json;

    final accessToken =
        (json['access_token'] ?? json['token'] ?? '').toString();

    return AuthSession(
      user: AuthUser.fromJson(userJson),
      accessToken: accessToken,
      refreshToken: json['refresh_token']?.toString(),
    );
  }
}
