enum AdminSeasonStatus { active, closed }

class AdminSeason {
  const AdminSeason({
    required this.id,
    required this.name,
    required this.startDate,
    required this.status,
    this.endDate,
  });
  factory AdminSeason.fromJson(Map<String, dynamic> json) => AdminSeason(
    id: json['id'] as String,
    name: json['name'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
    status: AdminSeasonStatus.values.byName(json['status'] as String),
    endDate: json['end_date'] == null
        ? null
        : DateTime.parse(json['end_date'] as String),
  );
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final AdminSeasonStatus status;
}
