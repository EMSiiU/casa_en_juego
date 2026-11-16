import 'package:supabase_flutter/supabase_flutter.dart';

import '../../tasks/models/household_task.dart';
import '../models/admin_dashboard.dart';
import '../models/admin_failure.dart';
import '../models/admin_season.dart';
import '../models/task_draft.dart';

abstract interface class AdminRepository {
  Future<AdminDashboard> loadDashboard();
  Future<String> loadInviteCode(String seasonId);
  Future<List<AdminSeason>> loadClosedCycles();
  Future<SeasonSummary> loadClosedCycle(String id);
  Future<List<HouseholdTask>> loadTasks();
  Future<HouseholdTask> loadTask(String id);
  Future<void> saveTask({String? id, required TaskDraft draft});
  Future<void> closeSeason(String id);
}

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);
  final SupabaseClient _client;
  static const _seasonColumns =
      'id, name, start_date, end_date, status, planned_duration_days, planned_end_date';
  static const _taskColumns =
      'id, name, points, icon_name, is_active, is_daily_limited';

  @override
  Future<String> loadInviteCode(String seasonId) async =>
      await _client.rpc<String>(
        'get_or_create_cycle_invite',
        params: {'p_season_id': seasonId},
      );

  @override
  Future<AdminDashboard> loadDashboard() async {
    final row = await _client
        .from('seasons')
        .select(_seasonColumns)
        .eq('status', 'active')
        .maybeSingle();
    return AdminDashboard(
      active: row == null
          ? null
          : await _loadSummary(AdminSeason.fromJson(row)),
    );
  }

  Future<SeasonSummary> _loadSummary(
    AdminSeason season, {
    List<HouseholdTask> archivedCatalog = const [],
  }) async {
    const pageSize = 500;
    final logs = <AdminLog>[];
    var offset = 0;
    while (true) {
      final rows = await _client
          .from('task_logs')
          .select(
            'id, user_id, status, points_snapshot, requester_name_snapshot',
          )
          .eq('season_id', season.id)
          .order('requested_at')
          .order('id')
          .range(offset, offset + pageSize - 1);
      logs.addAll(rows.map(AdminLog.fromJson));
      if (rows.length < pageSize) {
        return SeasonSummary(
          season: season,
          logs: logs,
          archivedCatalog: archivedCatalog,
        );
      }
      offset += pageSize;
    }
  }

  @override
  Future<List<AdminSeason>> loadClosedCycles() async {
    const pageSize = 500;
    final cycles = <AdminSeason>[];
    var offset = 0;
    while (true) {
      final rows = await _client
          .from('seasons')
          .select(_seasonColumns)
          .eq('status', 'closed')
          .order('end_date', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + pageSize - 1);
      cycles.addAll(rows.map(AdminSeason.fromJson));
      if (rows.length < pageSize) return List.unmodifiable(cycles);
      offset += pageSize;
    }
  }

  @override
  Future<SeasonSummary> loadClosedCycle(String id) async {
    final row = await _client
        .from('seasons')
        .select(_seasonColumns)
        .eq('id', id)
        .eq('status', 'closed')
        .maybeSingle();
    if (row == null) {
      throw const AdminFailure('Ese ciclo no está disponible en tu historial.');
    }
    const pageSize = 500;
    final catalog = <HouseholdTask>[];
    for (var offset = 0; ; offset += pageSize) {
      final items = await _client
          .rpc<List<Map<String, dynamic>>>(
            'get_closed_cycle_catalog',
            params: {'p_season_id': id},
          )
          .order('name')
          .order('id')
          .range(offset, offset + pageSize - 1);
      catalog.addAll(items.map(HouseholdTask.fromJson));
      if (items.length < pageSize) break;
    }
    return _loadSummary(AdminSeason.fromJson(row), archivedCatalog: catalog);
  }

  @override
  Future<List<HouseholdTask>> loadTasks() async {
    const pageSize = 500;
    final tasks = <HouseholdTask>[];
    var offset = 0;
    while (true) {
      final rows = await _client
          .from('tasks')
          .select(_taskColumns)
          .order('name')
          .order('id')
          .range(offset, offset + pageSize - 1);
      tasks.addAll(rows.map(HouseholdTask.fromJson));
      if (rows.length < pageSize) return List.unmodifiable(tasks);
      offset += pageSize;
    }
  }

  @override
  Future<HouseholdTask> loadTask(String id) async {
    final row = await _client
        .from('tasks')
        .select(_taskColumns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw const AdminFailure(
        'La tarea ya no está disponible. Actualiza el catálogo.',
      );
    }
    return HouseholdTask.fromJson(row);
  }

  @override
  Future<void> saveTask({String? id, required TaskDraft draft}) async {
    if (id == null) {
      await _client.from('tasks').insert(draft.toJson()).select('id').single();
    } else {
      final row = await _client
          .from('tasks')
          .update(draft.toJson())
          .eq('id', id)
          .select('id')
          .maybeSingle();
      if (row == null) {
        throw const AdminFailure(
          'La tarea no se pudo actualizar. Revisa tus permisos.',
        );
      }
    }
  }

  @override
  Future<void> closeSeason(String id) async {
    // El trigger del servidor asigna end_date y evita reabrir ciclos cerrados.
    final row = await _client
        .from('seasons')
        .update({'status': 'closed'})
        .eq('id', id)
        .eq('status', 'active')
        .select('id')
        .maybeSingle();
    if (row == null) {
      throw const AdminFailure(
        'Ese ciclo ya no está activo. Actualiza el panel.',
      );
    }
  }
}
