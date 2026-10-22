import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_entry.dart';
import '../models/activity_filter.dart';
import '../models/activity_page_state.dart';

abstract interface class ActivityRepository {
  Future<ActivityPageState> loadPage({
    required String userId,
    required ActivityFilter filter,
    required int offset,
    required int limit,
  });
}

class SupabaseActivityRepository implements ActivityRepository {
  SupabaseActivityRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<ActivityPageState> loadPage({
    required String userId,
    required ActivityFilter filter,
    required int offset,
    required int limit,
  }) async {
    // Se especifica la FK porque task_logs tiene dos referencias a users.
    // El historial incluye ciclos cerrados, sin depender de una temporada activa.
    var query = _client
        .from('task_logs')
        .select(
          'id, user_id, status, points_snapshot, requested_at, resolved_at, '
          'tasks(name), seasons(name, status), reviewer:users!task_logs_approved_by_fkey(name)',
        )
        .eq('user_id', userId);
    if (filter.status != null) query = query.eq('status', filter.status!.name);
    // Una fila extra permite saber si existe una página siguiente.
    final rows = await query
        .order('requested_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit);
    return ActivityPageState(
      entries: rows.take(limit).map(ActivityEntry.fromJson).toList(),
      hasMore: rows.length > limit,
    );
  }
}
