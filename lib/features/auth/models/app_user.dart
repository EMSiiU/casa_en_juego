enum UserRole { admin, sibling }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.notificationsEnabled,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    role: UserRole.values.byName(json['role'] as String),
    notificationsEnabled: json['notifications_enabled'] as bool,
  );

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool notificationsEnabled;

  bool get isAdmin => role == UserRole.admin;
}
