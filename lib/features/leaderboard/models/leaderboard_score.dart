import '../../../core/constants/task_log_status.dart';

class LeaderboardScore {
  const LeaderboardScore({
    required this.id,
    required this.userId,
    required this.taskId,
    required this.seasonId,
    required this.status,
    required this.pointsSnapshot,
    required this.taskName,
    required this.iconName,
  });

  factory LeaderboardScore.fromJson(Map<String, dynamic> json) {
    final task = json['tasks'] as Map<String, dynamic>;
    return LeaderboardScore(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      taskId: json['task_id'] as String,
      seasonId: json['season_id'] as String,
      status: TaskLogStatus.values.byName(json['status'] as String),
      pointsSnapshot: json['points_snapshot'] as int,
      taskName: task['name'] as String,
      iconName: task['icon_name'] as String,
    );
  }
  final String id;
  final String userId;
  final String taskId;
  final String seasonId;
  final TaskLogStatus status;
  final int pointsSnapshot;
  final String taskName;
  final String iconName;
}
