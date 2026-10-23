import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/household_task.dart';
import '../models/season.dart';
import '../models/task_log.dart';
import '../models/tasks_dashboard.dart';
import '../models/task_submission_status.dart';

abstract interface class TasksRepository {
  Future<TasksDashboard> loadDashboard();
  Future<void> submitTask({
    required String userId,
    required String taskId,
    required String seasonId,
  });
}

class SupabaseTasksRepository implements TasksRepository {
  SupabaseTasksRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<TasksDashboard> loadDashboard() async {
    final seasonData = await _client
        .from('seasons')
        .select('id, name, start_date')
        .eq('status', 'active')
        .maybeSingle();
    if (seasonData == null) {
      return TasksDashboard(season: null, tasks: [], logs: []);
    }
    final season = Season.fromJson(seasonData);
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _client
          .from('tasks')
          .select('id, name, points, icon_name, is_active, is_daily_limited')
          .eq('is_active', true)
          .order('name'),
      _loadLogs(season.id),
    ]);
    return TasksDashboard(
      season: season,
      submissionStatus: TaskSubmissionStatus.fromJson(
        Map<String, dynamic>.from(
          await _client.rpc('get_task_submission_status') as Map,
        ),
      ),
      tasks: results[0].map(HouseholdTask.fromJson).toList(),
      logs: results[1].map(TaskLog.fromJson).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _loadLogs(String seasonId) async {
    // La paginación evita truncar los puntos al límite de filas de Supabase.
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await _client
          .from('task_logs')
          .select(
            'id, user_id, task_id, season_id, status, points_snapshot, requested_at, tasks(name)',
          )
          .eq('season_id', seasonId)
          .inFilter('status', ['pending', 'approved'])
          .order('id')
          .range(offset, offset + pageSize - 1);
      rows.addAll(page);
      if (page.length < pageSize) return rows;
      offset += pageSize;
    }
  }

  @override
  Future<void> submitTask({
    required String userId,
    required String taskId,
    required String seasonId,
  }) async {
    // El servidor fija estado, fecha y puntos; el cliente solo envía referencias.
    await _client.from('task_logs').insert({
      'user_id': userId,
      'task_id': taskId,
      'season_id': seasonId,
    });
  }
}
