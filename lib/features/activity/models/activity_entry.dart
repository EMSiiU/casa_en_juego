import '../../../core/constants/task_log_status.dart';

class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.userId,
    required this.taskName,
    required this.seasonName,
    required this.isSeasonClosed,
    required this.status,
    required this.pointsSnapshot,
    required this.requestedAt,
    this.reviewerName,
    this.resolvedAt,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    final task = json['tasks'] as Map<String, dynamic>;
    final season = json['seasons'] as Map<String, dynamic>;
    final reviewer = json['reviewer'] as Map<String, dynamic>?;
    return ActivityEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      taskName: task['name'] as String,
      seasonName: season['name'] as String,
      isSeasonClosed: season['status'] == 'closed',
      status: TaskLogStatus.values.byName(json['status'] as String),
      pointsSnapshot: json['points_snapshot'] as int,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      reviewerName: reviewer?['name'] as String?,
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String taskName;
  final String seasonName;
  final bool isSeasonClosed;
  final TaskLogStatus status;
  final int pointsSnapshot;
  final DateTime requestedAt;
  final String? reviewerName;
  final DateTime? resolvedAt;

  int get awardedPoints =>
      status == TaskLogStatus.approved ? pointsSnapshot : 0;
}
