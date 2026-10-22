import 'dart:async';

import 'package:casa_en_juego/features/reviews/models/review_decision.dart';
import 'package:casa_en_juego/features/reviews/models/review_request.dart';
import 'package:casa_en_juego/features/reviews/repositories/reviews_repository.dart';

ReviewRequest reviewRequest({
  String id = 'request-id',
  String userId = 'luis-id',
  String name = 'Luis',
}) => ReviewRequest(
  id: id,
  userId: userId,
  requesterName: name,
  taskName: 'Limpiar el baño',
  iconName: 'bathtub',
  pointsSnapshot: 8,
  requestedAt: DateTime.utc(2026, 10, 22, 15, 28, 43),
  seasonName: 'Octubre 2026',
);

class FakeReviewsRepository implements ReviewsRepository {
  List<ReviewRequest> requests = [];
  Object? loadError;
  Object? resolveError;
  Completer<void>? pendingResolution;
  int resolveCalls = 0;
  ReviewDecision? decision;
  String? reviewerId;

  @override
  Future<List<ReviewRequest>> loadInbox(String userId) async {
    if (loadError != null) throw loadError!;
    return requests.where((request) => request.userId != userId).toList();
  }

  @override
  Future<void> resolve({
    required String requestId,
    required String reviewerId,
    required ReviewDecision decision,
  }) async {
    resolveCalls++;
    this.reviewerId = reviewerId;
    this.decision = decision;
    if (pendingResolution != null) await pendingResolution!.future;
    if (resolveError != null) throw resolveError!;
    requests = requests.where((request) => request.id != requestId).toList();
  }
}
