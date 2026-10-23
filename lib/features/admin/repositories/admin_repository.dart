import 'package:supabase_flutter/supabase_flutter.dart';

import '../../tasks/models/household_task.dart';
import '../models/admin_dashboard.dart';
import '../models/admin_failure.dart';
import '../models/admin_season.dart';
import '../models/task_draft.dart';

abstract interface class AdminRepository {
  Future<AdminDashboard> loadDashboard();
  Future<List<HouseholdTask>> loadTasks();
  Future<HouseholdTask> loadTask(String id);
  Future<void> saveTask({String? id, required TaskDraft draft});
  Future<void> closeSeason(String id);
  Future<void> startSeason(String name);
}

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);
  final SupabaseClient _client;
  static const _seasonColumns = 'id, name, start_date, end_date, status';
  static const _taskColumns = 'id, name, points, icon_name, is_active';

  @override
  Future<AdminDashboard> loadDashboard() async {
    final rows = await Future.wait<Map<String, dynamic>?>([
      _client
          .from('seasons')
          .select(_seasonColumns)
          .eq('status', 'active')
          .maybeSingle(),
      _client
          .from('seasons')
          .select(_seasonColumns)
          .eq('status', 'closed')
          .order('end_date', ascending: false)
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle(),
    ]);
    final summaries = await Future.wait<SeasonSummary?>([
      for (final row in rows)
        row == null
            ? Future.value(null)
            : _loadSummary(AdminSeason.fromJson(row)),
    ]);
    return AdminDashboard(active: summaries[0], latestClosed: summaries[1]);
  }

  Future<SeasonSummary> _loadSummary(AdminSeason season) async {
    const pageSize = 500;
    final logs = <AdminLog>[];
    var offset = 0;
    while (true) {
      final rows = await _client
          .from('task_logs')
          .select(
            'id, user_id, status, points_snapshot, requester:users!task_logs_user_id_fkey(name)',
          )
          .eq('season_id', season.id)
          .order('id')
          .range(offset, offset + pageSize - 1);
      logs.addAll(rows.map(AdminLog.fromJson));
      if (rows.length < pageSize) {
        return SeasonSummary(season: season, logs: logs);
      }
      offset += pageSize;
    }
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

  @override
  Future<void> startSeason(String name) async {
    // El índice único garantiza un solo ciclo activo, incluso con dos administradores.
    await _client
        .from('seasons')
        .insert({'name': name.trim()})
        .select('id')
        .single();
  }
}
