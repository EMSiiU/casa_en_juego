import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/review_decision.dart';
import '../models/review_failure.dart';
import '../models/review_request.dart';

abstract interface class ReviewsRepository {
  Future<List<ReviewRequest>> loadInbox(String userId);
  Future<void> resolve({
    required String requestId,
    required String reviewerId,
    required ReviewDecision decision,
  });
}

class SupabaseReviewsRepository implements ReviewsRepository {
  SupabaseReviewsRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<ReviewRequest>> loadInbox(String userId) async {
    const pageSize = 500;
    final requests = <ReviewRequest>[];
    var offset = 0;
    while (true) {
      final rows = await _client
          .from('task_logs')
          .select(
            'id, user_id, points_snapshot, requested_at, '
            'requester:users!task_logs_user_id_fkey(name), tasks(name, icon_name), seasons!inner(name, status)',
          )
          .eq('status', 'pending')
          .neq('user_id', userId)
          .eq('seasons.status', 'active')
          .order('requested_at', ascending: false)
          .order('id')
          .range(offset, offset + pageSize - 1);
      requests.addAll(rows.map(ReviewRequest.fromJson));
      if (rows.length < pageSize) return List.unmodifiable(requests);
      offset += pageSize;
    }
  }

  @override
  Future<void> resolve({
    required String requestId,
    required String reviewerId,
    required ReviewDecision decision,
  }) async {
    // La condición pending y RLS evitan resolver dos veces o revisar tareas propias.
    // El trigger fija el revisor y la hora; esos campos no salen del cliente.
    final row = await _client
        .from('task_logs')
        .update({'status': decision.name})
        .eq('id', requestId)
        .eq('status', 'pending')
        .neq('user_id', reviewerId)
        .select('id')
        .maybeSingle();
    if (row == null) {
      throw const ReviewFailure(
        'La solicitud ya no está disponible. Actualiza la bandeja.',
      );
    }
  }
}
