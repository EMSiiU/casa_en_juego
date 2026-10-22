import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/activity_failure.dart';
import '../models/activity_filter.dart';
import '../models/activity_page_state.dart';
import '../repositories/activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => SupabaseActivityRepository(ref.watch(supabaseClientProvider)),
);

final activityFilterProvider =
    NotifierProvider.autoDispose<ActivityFilterController, ActivityFilter>(
      ActivityFilterController.new,
    );

class ActivityFilterController extends Notifier<ActivityFilter> {
  @override
  ActivityFilter build() => ActivityFilter.all;
  void select(ActivityFilter filter) => state = filter;
}

final activityProvider =
    AsyncNotifierProvider.autoDispose<ActivityController, ActivityPageState>(
      ActivityController.new,
      retry: (retryCount, error) => null,
    );

class ActivityController extends AsyncNotifier<ActivityPageState> {
  static const pageSize = 20;
  int _generation = 0;
  int _nextOffset = 0;

  @override
  Future<ActivityPageState> build() async {
    _generation++;
    _nextOffset = 0;
    final user = ref.watch(currentUserProvider).asData?.value;
    final filter = ref.watch(activityFilterProvider);
    final repository = ref.watch(activityRepositoryProvider);
    if (user == null) {
      throw const ActivityFailure('Inicia sesión para ver tu actividad.');
    }
    final generation = _generation;
    final page = await repository.loadPage(
      userId: user.id,
      filter: filter,
      offset: 0,
      limit: pageSize,
    );
    if (ref.mounted && generation == _generation) {
      _nextOffset = page.entries.length;
    }
    return page;
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    final user = ref.read(currentUserProvider).asData?.value;
    if (state.isLoading ||
        current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        user == null) {
      return;
    }
    final generation = _generation;
    final filter = ref.read(activityFilterProvider);
    state = AsyncData(
      ActivityPageState(
        entries: current.entries,
        hasMore: true,
        isLoadingMore: true,
      ),
    );
    try {
      final next = await ref
          .read(activityRepositoryProvider)
          .loadPage(
            userId: user.id,
            filter: filter,
            offset: _nextOffset,
            limit: pageSize,
          );
      // Una respuesta antigua no debe reemplazar otro filtro ni otra sesión.
      if (!ref.mounted || generation != _generation) return;
      _nextOffset += next.entries.length;
      final seen = current.entries.map((entry) => entry.id).toSet();
      state = AsyncData(
        ActivityPageState(
          entries: [
            ...current.entries,
            ...next.entries.where((entry) => seen.add(entry.id)),
          ],
          hasMore: next.hasMore,
        ),
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        ActivityPageState(
          entries: current.entries,
          hasMore: true,
          loadMoreError: error,
        ),
      );
    }
  }
}
