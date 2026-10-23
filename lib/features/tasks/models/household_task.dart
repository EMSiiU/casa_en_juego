class HouseholdTask {
  const HouseholdTask({
    required this.id,
    required this.name,
    required this.points,
    required this.iconName,
    required this.isActive,
    this.isDailyLimited = false,
  });

  factory HouseholdTask.fromJson(Map<String, dynamic> json) => HouseholdTask(
    id: json['id'] as String,
    name: json['name'] as String,
    points: json['points'] as int,
    iconName: json['icon_name'] as String,
    isActive: json['is_active'] as bool,
    isDailyLimited: json['is_daily_limited'] as bool? ?? false,
  );

  final String id;
  final String name;
  final int points;
  final String iconName;
  final bool isActive;
  final bool isDailyLimited;
}
