class Season {
  const Season({required this.id, required this.name, required this.startDate});

  factory Season.fromJson(Map<String, dynamic> json) => Season(
    id: json['id'] as String,
    name: json['name'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
  );

  final String id;
  final String name;
  final DateTime startDate;
}
