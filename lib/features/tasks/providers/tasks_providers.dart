import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/task_failure.dart';
import '../models/tasks_dashboard.dart';
import '../repositories/tasks_repository.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return SupabaseTasksRepository(ref.watch(supabaseClientProvider));
});

final tasksDashboardProvider = FutureProvider.autoDispose<TasksDashboard>((
  ref,
) {
  final user = ref.watch(currentUserProvider).asData?.value;
  if (user == null) {
    throw const TaskFailure('Inicia sesión para ver tus tareas.');
  }
  return ref.watch(tasksRepositoryProvider).loadDashboard();
}, retry: (retryCount, error) => null);

final taskSubmissionProvider =
    AsyncNotifierProvider.autoDispose<TaskSubmissionController, void>(
      TaskSubmissionController.new,
    );

class TaskSubmissionController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> submit({
    required String taskId,
    required String seasonId,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final user = ref.read(currentUserProvider).asData?.value;
      final dashboard = ref.read(tasksDashboardProvider).asData?.value;
      if (user == null) {
        throw const TaskFailure('Tu sesión terminó. Vuelve a iniciar sesión.');
      }
      if (dashboard?.season?.id != seasonId ||
          !dashboard!.tasks.any((task) => task.id == taskId && task.isActive)) {
        throw const TaskFailure(
          'El ciclo o la tarea ya no están disponibles. Actualiza el inicio.',
        );
      }
      await ref
          .read(tasksRepositoryProvider)
          .submitTask(userId: user.id, taskId: taskId, seasonId: seasonId);
    });
    if (!ref.mounted) return false;
    state = result;
    // También refresca tras un rechazo por ciclo cerrado o tarea desactivada.
    ref.invalidate(tasksDashboardProvider);
    return !result.hasError;
  }
}
