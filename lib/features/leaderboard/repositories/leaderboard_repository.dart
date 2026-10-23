import 'package:supabase_flutter/supabase_flutter.dart';

import '../../tasks/models/season.dart';
import '../models/leaderboard_data.dart';
import '../models/leaderboard_member.dart';
import '../models/leaderboard_score.dart';

abstract interface class LeaderboardRepository {
  Future<LeaderboardData> loadLeaderboard();
}

class SupabaseLeaderboardRepository implements LeaderboardRepository {
  SupabaseLeaderboardRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<LeaderboardData> loadLeaderboard() async {
    final row = await _client
        .from('seasons')
        .select('id, name, start_date')
        .eq('status', 'active')
        .maybeSingle();
    if (row == null) {
      return LeaderboardData(season: null, members: [], scores: []);
    }
    final season = Season.fromJson(row);
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _loadMembers(),
      _loadScores(season.id),
    ]);
    return LeaderboardData(
      season: season,
      members: results[0].map(LeaderboardMember.fromJson).toList(),
      scores: results[1].map(LeaderboardScore.fromJson).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _loadMembers() async {
    // Incluye a quienes aún tienen cero puntos; no consulta correos ni roles.
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await _client
          .from('users')
          .select('id, name')
          .order('id')
          .range(offset, offset + pageSize - 1);
      rows.addAll(page);
      if (page.length < pageSize) return rows;
      offset += pageSize;
    }
  }

  Future<List<Map<String, dynamic>>> _loadScores(String seasonId) async {
    // Los puntos históricos provienen de cada solicitud, incluso de tareas inactivas.
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await _client
          .from('task_logs')
          .select(
            'id, user_id, task_id, season_id, status, points_snapshot, tasks(name, icon_name)',
          )
          .eq('season_id', seasonId)
          .eq('status', 'approved')
          .order('id')
          .range(offset, offset + pageSize - 1);
      rows.addAll(page);
      if (page.length < pageSize) return rows;
      offset += pageSize;
    }
  }
}
