import 'dart:async';

import 'package:casa_en_juego/core/constants/task_log_status.dart';
import 'package:casa_en_juego/features/admin/models/admin_dashboard.dart';
import 'package:casa_en_juego/features/admin/models/admin_failure.dart';
import 'package:casa_en_juego/features/admin/models/admin_season.dart';
import 'package:casa_en_juego/features/admin/models/task_draft.dart';
import 'package:casa_en_juego/features/admin/repositories/admin_repository.dart';
import 'package:casa_en_juego/features/auth/models/app_user.dart';
import 'package:casa_en_juego/features/tasks/models/household_task.dart';

import 'fake_tasks_repository.dart';

const adminUser = AppUser(
  id: 'admin-id',
  name: 'Carlos',
  email: 'carlos@familia.es',
  role: UserRole.admin,
  notificationsEnabled: true,
);
final adminSeason = AdminSeason(
  id: 'season-id',
  name: 'Octubre 2026',
  startDate: DateTime.utc(2026, 10),
  status: AdminSeasonStatus.active,
);
const adminLogs = [
  AdminLog(
    id: 'approved',
    userId: 'member-id',
    userName: 'Ana',
    status: TaskLogStatus.approved,
    points: 8,
  ),
  AdminLog(
    id: 'pending',
    userId: 'luis-id',
    userName: 'Luis',
    status: TaskLogStatus.pending,
    points: 3,
  ),
];

class FakeAdminRepository implements AdminRepository {
  AdminDashboard dashboard = AdminDashboard(
    active: SeasonSummary(season: adminSeason, logs: adminLogs),
  );
  List<HouseholdTask> tasks = [testTask];
  Object? loadError;
  Object? mutationError;
  Completer<void>? pendingMutation;
  int saveCalls = 0;
  int closeCalls = 0;
  int startCalls = 0;
  TaskDraft? savedDraft;

  @override
  Future<AdminDashboard> loadDashboard() async {
    if (loadError != null) throw loadError!;
    return dashboard;
  }

  @override
  Future<List<HouseholdTask>> loadTasks() async => tasks;
  @override
  Future<HouseholdTask> loadTask(String id) async =>
      tasks.firstWhere((task) => task.id == id);
  Future<void> _wait() async {
    if (pendingMutation != null) await pendingMutation!.future;
    if (mutationError != null) throw mutationError!;
  }

  @override
  Future<void> saveTask({String? id, required TaskDraft draft}) async {
    saveCalls++;
    savedDraft = draft;
    await _wait();
    final saved = HouseholdTask(
      id: id ?? 'created-$saveCalls',
      name: draft.name,
      points: draft.points,
      iconName: draft.iconName,
      isActive: draft.isActive,
      isDailyLimited: draft.isDailyLimited,
    );
    tasks = [...tasks.where((task) => task.id != saved.id), saved];
  }

  @override
  Future<void> closeSeason(String id) async {
    closeCalls++;
    await _wait();
    final current = dashboard.active;
    if (current == null || current.season.id != id) {
      throw const AdminFailure('Ciclo no disponible');
    }
    dashboard = AdminDashboard(
      latestClosed: SeasonSummary(
        season: AdminSeason(
          id: id,
          name: current.season.name,
          startDate: current.season.startDate,
          endDate: DateTime.utc(2026, 10, 22, 20),
          status: AdminSeasonStatus.closed,
        ),
        logs: current.logs,
      ),
    );
  }

  @override
  Future<void> startSeason(String name) async {
    startCalls++;
    await _wait();
    dashboard = AdminDashboard(
      active: SeasonSummary(
        season: AdminSeason(
          id: 'new-season',
          name: name,
          startDate: DateTime.utc(2026, 11),
          status: AdminSeasonStatus.active,
        ),
        logs: [],
      ),
      latestClosed: dashboard.latestClosed,
    );
  }
}
