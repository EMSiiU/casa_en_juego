import 'dart:async';

import 'package:casa_en_juego/features/tasks/models/household_task.dart';
import 'package:casa_en_juego/features/tasks/models/season.dart';
import 'package:casa_en_juego/features/tasks/models/task_log.dart';
import 'package:casa_en_juego/features/tasks/models/tasks_dashboard.dart';
import 'package:casa_en_juego/features/tasks/repositories/tasks_repository.dart';

const testTask = HouseholdTask(
  id: 'task-id',
  name: 'Barrer el cuarto',
  points: 3,
  iconName: 'broom',
  isActive: true,
);

final testSeason = Season(
  id: 'season-id',
  name: 'Octubre 2026',
  startDate: DateTime.utc(2026, 10),
);

TaskLog testLog({
  String id = 'log-id',
  String userId = 'member-id',
  String seasonId = 'season-id',
  TaskLogStatus status = TaskLogStatus.pending,
  int points = 3,
}) => TaskLog(
  id: id,
  userId: userId,
  taskId: testTask.id,
  seasonId: seasonId,
  status: status,
  pointsSnapshot: points,
  requestedAt: DateTime.utc(2026, 10, 22),
  taskName: testTask.name,
);

class FakeTasksRepository implements TasksRepository {
  TasksDashboard dashboard = TasksDashboard(
    season: testSeason,
    tasks: [testTask],
    logs: [],
  );
  Object? loadError;
  Object? submitError;
  Completer<void>? pendingSubmission;
  int submitCalls = 0;
  String? submittedUserId;
  String? submittedTaskId;
  String? submittedSeasonId;

  @override
  Future<TasksDashboard> loadDashboard() async {
    if (loadError != null) throw loadError!;
    return dashboard;
  }

  @override
  Future<void> submitTask({
    required String userId,
    required String taskId,
    required String seasonId,
  }) async {
    submitCalls++;
    submittedUserId = userId;
    submittedTaskId = taskId;
    submittedSeasonId = seasonId;
    if (pendingSubmission != null) await pendingSubmission!.future;
    if (submitError != null) throw submitError!;
    dashboard = TasksDashboard(
      season: dashboard.season,
      tasks: dashboard.tasks,
      logs: [
        ...dashboard.logs,
        testLog(id: 'submitted-$submitCalls', userId: userId),
      ],
    );
  }
}
