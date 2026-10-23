import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../tasks/presentation/widgets/task_icon.dart';
import '../models/admin_failure.dart';
import '../providers/admin_providers.dart';
import 'widgets/admin_scaffold.dart';

class TaskCatalogPage extends ConsumerWidget {
  const TaskCatalogPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(adminTasksProvider);
    final busy = ref.watch(adminActionProvider).isBusy;
    return AdminScaffold(
      title: 'Gestionar tareas',
      subtitle: 'ADMINISTRADOR · CATÁLOGO',
      isBusy: busy,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminTasksProvider);
          try {
            await ref.read(adminTasksProvider.future);
          } catch (_) {
            /* La vista muestra el error. */
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () {
                      ref.read(adminActionProvider.notifier).clearError();
                      context.pushNamed('adminNewTask');
                    },
              icon: const Icon(Icons.add),
              label: const Text('Nueva tarea'),
            ),
            const SizedBox(height: 18),
            tasks.when(
              skipLoadingOnRefresh: false,
              loading: () => const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => AdminLoadError(
                message: AdminFailure.messageFor(error),
                onRetry: () => ref.invalidate(adminTasksProvider),
              ),
              data: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${items.length} tareas · ${items.where((task) => task.isActive).length} disponibles para registrar',
                    style: const TextStyle(
                      color: Color(0xFFB8B9C9),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aún no hay tareas. Crea la primera tarea del catálogo.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final task in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: TaskIcon(iconName: task.iconName),
                          title: Text(task.name),
                          subtitle: Text(
                            '${task.points} puntos · ${task.isActive ? 'Activa' : 'Inactiva'} · ${task.isDailyLimited ? 'Una vez al día' : 'Repetible'}',
                            style: TextStyle(
                              color: task.isActive
                                  ? const Color(0xFF91D5C6)
                                  : AppTheme.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.edit_outlined,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                          onTap: busy
                              ? null
                              : () {
                                  ref
                                      .read(adminActionProvider.notifier)
                                      .clearError();
                                  ref.invalidate(adminTaskProvider(task.id));
                                  context.pushNamed(
                                    'adminEditTask',
                                    pathParameters: {'taskId': task.id},
                                  );
                                },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const AdminInfo(
              'Desactivar oculta la tarea del catálogo familiar, pero conserva todas sus solicitudes y su historial.',
            ),
          ],
        ),
      ),
    );
  }
}
