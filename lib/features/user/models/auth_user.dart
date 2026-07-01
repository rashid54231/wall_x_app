class AuthUser {
  final String id;
  final String email;
  final String? displayName;
  final String role;

  AuthUser({required this.id, required this.email, this.displayName, this.role = 'user'});

  bool get isAdmin => role == 'admin';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['user_metadata']?['full_name'] as String?,
      role: json['role'] as String? ?? 'user',
    );
  }
}
