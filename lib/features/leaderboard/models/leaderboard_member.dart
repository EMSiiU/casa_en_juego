class LeaderboardMember {
  const LeaderboardMember({required this.id, required this.name});
  factory LeaderboardMember.fromJson(Map<String, dynamic> json) =>
      LeaderboardMember(id: json['id'] as String, name: json['name'] as String);
  final String id;
  final String name;
}
