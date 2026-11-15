enum UserRole { admin, sibling }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.notificationsEnabled,
    this.isHouseholdMember = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    role: UserRole.values.byName(json['role'] as String),
    notificationsEnabled: json['notifications_enabled'] as bool,
    isHouseholdMember: json['is_household_member'] as bool? ?? true,
  );

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool notificationsEnabled;
  final bool isHouseholdMember;

  bool get isAdmin => isHouseholdMember && role == UserRole.admin;
}
