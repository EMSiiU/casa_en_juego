import 'household_task.dart';
import 'season.dart';
import 'task_log.dart';
import 'task_submission_status.dart';

class TasksDashboard {
  TasksDashboard({
    required this.season,
    required List<HouseholdTask> tasks,
    required List<TaskLog> logs,
    this.submissionStatus,
  }) : tasks = List.unmodifiable(tasks),
       logs = List.unmodifiable(logs);

  final Season? season;
  final List<HouseholdTask> tasks;
  final List<TaskLog> logs;
  final TaskSubmissionStatus? submissionStatus;

  // Se filtra por ciclo incluso cuando el repositorio ya aplica ese filtro.
  Iterable<TaskLog> get _currentLogs =>
      logs.where((log) => season != null && log.seasonId == season!.id);

  int approvedPointsFor(String userId) => _currentLogs
      .where(
        (log) => log.userId == userId && log.status == TaskLogStatus.approved,
      )
      .fold(0, (total, log) => total + log.pointsSnapshot);

  List<TaskLog> pendingFor(String userId) => _currentLogs
      .where(
        (log) => log.userId == userId && log.status == TaskLogStatus.pending,
      )
      .toList();

  int? positionFor(String userId) {
    final points = approvedPointsFor(userId);
    if (points == 0) return null;
    final totals = <String, int>{};
    for (final log in _currentLogs) {
      if (log.status == TaskLogStatus.approved) {
        totals.update(
          log.userId,
          (total) => total + log.pointsSnapshot,
          ifAbsent: () => log.pointsSnapshot,
        );
      }
    }
    // Los empates comparten posición: 1, 1, 3.
    return 1 + totals.values.where((total) => total > points).length;
  }
}
