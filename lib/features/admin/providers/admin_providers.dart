import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../tasks/models/household_task.dart';
import '../../tasks/providers/tasks_providers.dart';
import '../../activity/providers/activity_providers.dart';
import '../../leaderboard/providers/leaderboard_providers.dart';
import '../../reviews/providers/reviews_providers.dart';
import '../models/admin_action_state.dart';
import '../models/admin_dashboard.dart';
import '../models/admin_failure.dart';
import '../models/task_draft.dart';
import '../repositories/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => SupabaseAdminRepository(ref.watch(supabaseClientProvider)),
);

void _requireAdmin(Ref ref) {
  if (ref.watch(currentUserProvider).asData?.value?.isAdmin != true) {
    throw const AdminFailure(
      'Esta sección requiere una cuenta de administrador.',
    );
  }
}

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>((
  ref,
) {
  _requireAdmin(ref);
  return ref.watch(adminRepositoryProvider).loadDashboard();
}, retry: (retryCount, error) => null);

final adminTasksProvider = FutureProvider.autoDispose<List<HouseholdTask>>((
  ref,
) {
  _requireAdmin(ref);
  return ref.watch(adminRepositoryProvider).loadTasks();
}, retry: (retryCount, error) => null);

final adminTaskProvider = FutureProvider.autoDispose
    .family<HouseholdTask, String>((ref, id) {
      _requireAdmin(ref);
      return ref.watch(adminRepositoryProvider).loadTask(id);
    }, retry: (retryCount, error) => null);

final adminActionProvider =
    NotifierProvider.autoDispose<AdminActionController, AdminActionState>(
      AdminActionController.new,
    );

class AdminActionController extends Notifier<AdminActionState> {
  @override
  AdminActionState build() {
    ref.watch(currentUserProvider);
    return const AdminActionState();
  }

  void clearError() {
    if (!state.isBusy) state = const AdminActionState();
  }

  Future<bool> saveTask({String? id, required TaskDraft draft}) =>
      _run((repository) => repository.saveTask(id: id, draft: draft));
  Future<bool> closeSeason(String id) => _run((repository) async {
    final current = ref.read(adminDashboardProvider).asData?.value;
    if (current?.active?.season.id != id) {
      throw const AdminFailure('El ciclo ya cambió. Actualiza el panel.');
    }
    await repository.closeSeason(id);
  });
  Future<bool> startSeason(String name) => _run((repository) async {
    if (name.trim().isEmpty || name.trim().length > 100) {
      throw const AdminFailure(
        'Escribe un nombre de ciclo de 1 a 100 caracteres.',
      );
    }
    final current = ref.read(adminDashboardProvider).asData?.value;
    if (current == null || current.active != null) {
      throw const AdminFailure(
        'Debe finalizar el ciclo activo antes de iniciar otro.',
      );
    }
    await repository.startSeason(name.trim());
  });

  Future<bool> _run(Future<void> Function(AdminRepository) operation) async {
    if (state.isBusy) return false;
    final user = ref.read(currentUserProvider).asData?.value;
    state = const AdminActionState(isBusy: true);
    try {
      if (user?.isAdmin != true) {
        throw const AdminFailure(
          'Esta acción requiere una cuenta de administrador.',
        );
      }
      await operation(ref.read(adminRepositoryProvider));
      if (!ref.mounted ||
          ref.read(currentUserProvider).asData?.value?.id != user!.id) {
        return false;
      }
      state = const AdminActionState();
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(adminTasksProvider);
      ref.invalidate(tasksDashboardProvider);
      ref.invalidate(leaderboardProvider);
      ref.invalidate(reviewsInboxProvider);
      ref.invalidate(activityProvider);
      return true;
    } catch (error) {
      if (!ref.mounted ||
          ref.read(currentUserProvider).asData?.value?.id != user?.id) {
        return false;
      }
      if (kDebugMode) {
        debugPrint(
          'admin.operation failed: ${error is PostgrestException ? '${error.code}: ${error.message}' : error.runtimeType}',
        );
      }
      state = AdminActionState(errorMessage: AdminFailure.messageFor(error));
      // Refrescar también ante conflictos entre dos administradores.
      ref.invalidate(adminDashboardProvider);
      return false;
    }
  }
}
