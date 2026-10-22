import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_navigation_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/household_task.dart';
import '../models/task_failure.dart';
import '../models/task_log.dart';
import '../models/tasks_dashboard.dart';
import '../providers/tasks_providers.dart';
import 'widgets/task_icon.dart';
import 'widgets/task_submission_sheet.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  late final AppLifecycleListener _lifecycle;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.invalidate(tasksDashboardProvider);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(tasksDashboardProvider);
    try {
      await ref.read(tasksDashboardProvider.future);
    } catch (_) {
      // El estado de error se muestra dentro de la lista y permite reintentar.
    }
  }

  Future<void> _confirmTask(HouseholdTask task, String seasonId) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    try {
      final sent = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: false,
        builder: (context) =>
            TaskSubmissionSheet(task: task, seasonId: seasonId),
      );
      if (mounted && sent == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Enviada a revisión. Tus puntos se sumarán cuando sea aprobada.',
            ),
            action: SnackBarAction(
              label: 'Ver actividad',
              onPressed: () => _openActivity(submitted: true),
            ),
          ),
        );
      }
    } finally {
      _sheetOpen = false;
    }
  }

  Future<void> _openActivity({bool submitted = false}) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await context.pushNamed<void>(
      'activity',
      queryParameters: submitted ? {'submitted': 'true'} : {},
    );
    if (mounted) ref.invalidate(tasksDashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final dashboard = ref.watch(tasksDashboardProvider);
    final authAction = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthFailure.messageFor(next.error!))),
        );
      }
    });
    final name = user?.name ?? '';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CASA EN JUEGO',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '¡Hola, $name!',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Abrir cuenta',
                        enabled: !authAction.isLoading,
                        onSelected: (_) =>
                            ref.read(authControllerProvider.notifier).signOut(),
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            enabled: false,
                            child: Text(
                              user?.isAdmin == true
                                  ? 'Administrador'
                                  : 'Miembro',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'signOut',
                            child: Text('Cerrar sesión'),
                          ),
                        ],
                        child: CircleAvatar(
                          backgroundColor: const Color(0xFF39334F),
                          foregroundColor: Colors.white,
                          child: authAction.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  dashboard.when(
                    skipLoadingOnRefresh: false,
                    loading: () => const SizedBox(
                      height: 250,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) => _StatusCard(
                      icon: Icons.cloud_off_outlined,
                      message: TaskFailure.messageFor(error),
                      action: FilledButton(
                        onPressed: _refresh,
                        child: const Text('Reintentar'),
                      ),
                    ),
                    data: (data) => data.season == null
                        ? const _StatusCard(
                            icon: Icons.event_busy_outlined,
                            title: 'No hay un ciclo activo',
                            message: 'El administrador debe iniciar una temporada para que puedas registrar tareas.',
                          )
                        : _buildDashboard(data, user?.id ?? ''),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppNavigationBar(),
    );
  }

  Widget _buildDashboard(TasksDashboard data, String userId) {
    final pending = data.pendingFor(userId);
    final points = data.approvedPointsFor(userId);
    final position = data.positionFor(userId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data.season!.name,
                style: const TextStyle(color: Color(0xFFB8B9C9)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF26413E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '● Ciclo activo',
                style: TextStyle(color: Color(0xFF91D5C6), fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF39334F),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$points',
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const TextSpan(
                            text: ' puntos',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'APROBADOS',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      position == null
                          ? 'Tu próxima tarea puede sumar. ¡Vamos!'
                          : 'Vas en $position.º lugar. ¡Sigue así!',
                      style: const TextStyle(
                        color: Color(0xFFB8B9C9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.emoji_events_outlined,
                size: 38,
                color: AppTheme.primary,
              ),
            ],
          ),
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Ver mis solicitudes pendientes',
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openActivity,
              child: _PendingBanner(logs: pending),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                '¿Qué hiciste hoy?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: _openActivity,
              child: const Text('Mi actividad →'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (data.tasks.isEmpty)
          const _StatusCard(
            icon: Icons.cleaning_services_outlined,
            title: 'Aún no hay tareas disponibles',
            message: 'El administrador puede añadir o activar tareas en el catálogo.',
          )
        else
          for (final task in data.tasks.where((task) => task.isActive))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _confirmTask(task, data.season!.id),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                    child: Row(
                      children: [
                        TaskIcon(iconName: task.iconName),
                        const SizedBox(width: 12),
                        Expanded(child: Text(task.name)),
                        const SizedBox(width: 8),
                        Text(
                          '+${task.points}',
                          style: const TextStyle(color: AppTheme.primary),
                        ),
                        IconButton(
                          tooltip: 'Registrar ${task.name}',
                          onPressed: () => _confirmTask(task, data.season!.id),
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        const SizedBox(height: 10),
        const Text(
          'Registra lo que termines. Otro miembro lo revisará.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFB8B9C9), fontSize: 12),
        ),
      ],
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.logs});
  final List<TaskLog> logs;

  @override
  Widget build(BuildContext context) {
    final points = logs.fold(0, (total, log) => total + log.pointsSnapshot);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF423B2F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Color(0xFFF2C978), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${logs.length} ${logs.length == 1 ? 'tarea' : 'tareas'} en revisión · +$points pts',
                  style: const TextStyle(
                    color: Color(0xFFF2C978),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  logs.length == 1
                      ? '${logs.first.taskName} · Aún no suma'
                      : 'Aún no suman al ranking',
                  style: const TextStyle(
                    color: Color(0xFFCBC4B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.message,
    this.title,
    this.action,
  });
  final IconData icon;
  final String message;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppTheme.primary),
          const SizedBox(height: 16),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB8B9C9), height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
