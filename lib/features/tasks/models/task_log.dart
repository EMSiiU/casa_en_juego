import '../../../core/constants/task_log_status.dart';

export '../../../core/constants/task_log_status.dart';

class TaskLog {
  const TaskLog({
    required this.id,
    required this.userId,
    required this.taskId,
    required this.seasonId,
    required this.status,
    required this.pointsSnapshot,
    required this.requestedAt,
    required this.taskName,
  });

  factory TaskLog.fromJson(Map<String, dynamic> json) => TaskLog(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    taskId: json['task_id'] as String,
    seasonId: json['season_id'] as String,
    status: TaskLogStatus.values.byName(json['status'] as String),
    pointsSnapshot: json['points_snapshot'] as int,
    requestedAt: DateTime.parse(json['requested_at'] as String),
    taskName: (json['tasks'] as Map<String, dynamic>)['name'] as String,
  );

  final String id;
  final String userId;
  final String taskId;
  final String seasonId;
  final TaskLogStatus status;
  final int pointsSnapshot;
  final DateTime requestedAt;
  final String taskName;
}
