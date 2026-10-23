import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../activity/providers/activity_providers.dart';
import '../../tasks/providers/tasks_providers.dart';
import '../../leaderboard/providers/leaderboard_providers.dart';
import '../models/review_action_state.dart';
import '../models/review_decision.dart';
import '../models/review_failure.dart';
import '../models/review_request.dart';
import '../repositories/reviews_repository.dart';

final reviewsRepositoryProvider = Provider<ReviewsRepository>(
  (ref) => SupabaseReviewsRepository(ref.watch(supabaseClientProvider)),
);

final reviewsInboxProvider = FutureProvider.autoDispose<List<ReviewRequest>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider).asData?.value;
  if (user == null) return const [];
  final repository = ref.watch(reviewsRepositoryProvider);
  try {
    return await repository.loadInbox(user.id);
  } catch (error) {
    if (kDebugMode) {
      // El diagnóstico omite claves, tokens y el contenido de las solicitudes.
      debugPrint(
        'reviews.loadInbox failed: ${error is PostgrestException ? '${error.code}: ${error.message}' : error.runtimeType}',
      );
    }
    rethrow;
  }
}, retry: (retryCount, error) => null);

final reviewActionProvider =
    NotifierProvider.autoDispose<ReviewActionController, ReviewActionState>(
      ReviewActionController.new,
    );

class ReviewActionController extends Notifier<ReviewActionState> {
  void clearError() {
    if (!state.isBusy) state = const ReviewActionState();
  }

  @override
  ReviewActionState build() {
    ref.watch(currentUserProvider);
    return const ReviewActionState();
  }

  Future<bool> resolve(String requestId, ReviewDecision decision) async {
    if (state.isBusy) return false;
    final userId = ref.read(currentUserProvider).asData?.value?.id;
    state = ReviewActionState(busyId: requestId);
    try {
      final inbox = ref.read(reviewsInboxProvider).asData?.value;
      if (userId == null ||
          inbox == null ||
          !inbox.any(
            (request) => request.id == requestId && request.userId != userId,
          )) {
        throw const ReviewFailure(
          'Solo puedes revisar solicitudes pendientes de otros miembros.',
        );
      }
      await ref
          .read(reviewsRepositoryProvider)
          .resolve(
            requestId: requestId,
            reviewerId: userId,
            decision: decision,
          );
      if (!ref.mounted ||
          ref.read(currentUserProvider).asData?.value?.id != userId) {
        return false;
      }
      state = const ReviewActionState();
      ref.invalidate(reviewsInboxProvider);
      ref.invalidate(tasksDashboardProvider);
      ref.invalidate(leaderboardProvider);
      ref.invalidate(activityProvider);
      return true;
    } catch (error) {
      if (!ref.mounted ||
          ref.read(currentUserProvider).asData?.value?.id != userId) {
        return false;
      }
      state = ReviewActionState(
        errorMessage: ReviewFailure.messageFor(error, deciding: true),
      );
      ref.invalidate(reviewsInboxProvider);
      return false;
    }
  }
}
