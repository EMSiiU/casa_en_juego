import '../../../core/constants/task_log_status.dart';
import 'admin_season.dart';

class AdminLog {
  const AdminLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.status,
    required this.points,
  });
  factory AdminLog.fromJson(Map<String, dynamic> json) => AdminLog(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    userName: (json['requester'] as Map<String, dynamic>)['name'] as String,
    status: TaskLogStatus.values.byName(json['status'] as String),
    points: json['points_snapshot'] as int,
  );
  final String id;
  final String userId;
  final String userName;
  final TaskLogStatus status;
  final int points;
}

class SeasonResult {
  const SeasonResult({
    required this.userId,
    required this.name,
    required this.points,
    required this.position,
  });
  final String userId;
  final String name;
  final int points;
  final int position;
}

class SeasonSummary {
  SeasonSummary({required this.season, required List<AdminLog> logs})
    : logs = List.unmodifiable(logs);
  final AdminSeason season;
  final List<AdminLog> logs;
  int get approvedPoints => logs
      .where((log) => log.status == TaskLogStatus.approved)
      .fold(0, (total, log) => total + log.points);
  int get participants => logs.map((log) => log.userId).toSet().length;
  int get pendingCount =>
      logs.where((log) => log.status == TaskLogStatus.pending).length;

  List<SeasonResult> get results {
    final totals = <String, int>{};
    final names = <String, String>{};
    for (final log in logs) {
      names[log.userId] = log.userName;
      totals.putIfAbsent(log.userId, () => 0);
      if (log.status == TaskLogStatus.approved) {
        totals[log.userId] = totals[log.userId]! + log.points;
      }
    }
    final ids = totals.keys.toList()
      ..sort((a, b) {
        final byPoints = totals[b]!.compareTo(totals[a]!);
        return byPoints == 0 ? a.compareTo(b) : byPoints;
      });
    return ids
        .map(
          (id) => SeasonResult(
            userId: id,
            name: names[id]!,
            points: totals[id]!,
            position:
                1 +
                totals.values.where((points) => points > totals[id]!).length,
          ),
        )
        .toList();
  }
}

class AdminDashboard {
  const AdminDashboard({this.active, this.latestClosed});
  final SeasonSummary? active;
  final SeasonSummary? latestClosed;
}
