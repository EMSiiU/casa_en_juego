enum UserRole { admin, sibling }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.notificationsEnabled,
    this.isHouseholdMember = true,
    this.avatarUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json, {String? avatarUrl}) =>
      AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: UserRole.values.byName(json['role'] as String),
        notificationsEnabled: json['notifications_enabled'] as bool,
        isHouseholdMember: json['is_household_member'] as bool? ?? true,
        avatarUrl: avatarUrl,
      );

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool notificationsEnabled;
  final bool isHouseholdMember;
  final String? avatarUrl;

  AppUser withName(String name) => AppUser(
    id: id,
    name: name,
    email: email,
    role: role,
    notificationsEnabled: notificationsEnabled,
    isHouseholdMember: isHouseholdMember,
    avatarUrl: avatarUrl,
  );

  bool get isAdmin => isHouseholdMember && role == UserRole.admin;
}
