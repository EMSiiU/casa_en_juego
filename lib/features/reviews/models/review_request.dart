class ReviewRequest {
  const ReviewRequest({
    required this.id,
    required this.userId,
    required this.requesterName,
    required this.taskName,
    required this.iconName,
    required this.pointsSnapshot,
    required this.requestedAt,
    required this.seasonName,
  });

  factory ReviewRequest.fromJson(Map<String, dynamic> json) {
    final requester = json['requester'] as Map<String, dynamic>;
    final task = json['tasks'] as Map<String, dynamic>;
    final season = json['seasons'] as Map<String, dynamic>;
    return ReviewRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      requesterName: requester['name'] as String,
      taskName: task['name'] as String,
      iconName: task['icon_name'] as String,
      pointsSnapshot: json['points_snapshot'] as int,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      seasonName: season['name'] as String,
    );
  }

  final String id;
  final String userId;
  final String requesterName;
  final String taskName;
  final String iconName;
  final int pointsSnapshot;
  final DateTime requestedAt;
  final String seasonName;
}
