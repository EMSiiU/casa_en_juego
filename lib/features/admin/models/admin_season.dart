enum AdminSeasonStatus { active, closed }

class AdminSeason {
  const AdminSeason({
    required this.id,
    required this.name,
    required this.startDate,
    required this.status,
    this.endDate,
    this.plannedDurationDays,
    this.plannedEndDate,
  });
  factory AdminSeason.fromJson(Map<String, dynamic> json) => AdminSeason(
    id: json['id'] as String,
    name: json['name'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
    status: AdminSeasonStatus.values.byName(json['status'] as String),
    plannedDurationDays: json['planned_duration_days'] as int?,
    plannedEndDate: switch (json['planned_end_date']) {
      final String date => DateTime.parse(date),
      _ => null,
    },
    endDate: json['end_date'] == null
        ? null
        : DateTime.parse(json['end_date'] as String),
  );
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final int? plannedDurationDays;
  final DateTime? plannedEndDate;
  final AdminSeasonStatus status;
}
