import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_navigation_bar.dart';
import '../../../core/theme/app_page_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/widgets/account_menu.dart';
import '../../auth/providers/auth_providers.dart';
import '../../reviews/providers/reviews_providers.dart';
import '../models/household_task.dart';
import '../models/task_failure.dart';
import '../models/task_log.dart';
import '../models/tasks_dashboard.dart';
import '../providers/tasks_providers.dart';
import '../providers/shake_provider.dart';
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
  Timer? _dayTimer;

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
    _dayTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(reviewsInboxProvider);
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
            duration: const Duration(seconds: 3),
            persist: false,
            content: const Text('Enviada a revisión.'),
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

  Future<void> _suggestTask() async {
    if (_sheetOpen ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final dashboard = ref.read(tasksDashboardProvider);
    if (dashboard.isLoading || dashboard.hasError) return;
    final tasks = dashboard.asData?.value.availableForSuggestion ?? [];
    if (tasks.isEmpty) return;
    final task = tasks[Random().nextInt(tasks.length)];
    _sheetOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tarea sugerida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TaskIcon(iconName: task.iconName, size: 48),
              const SizedBox(height: 12),
              Text(task.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              const Text('Cuando la termines, regístrala desde la lista.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } finally {
      _sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final dashboard = ref.watch(tasksDashboardProvider);
    if (ModalRoute.of(context)?.isCurrent == true &&
        !dashboard.isLoading &&
        !dashboard.hasError &&
        dashboard.asData?.value.availableForSuggestion.isNotEmpty == true) {
      ref.listen(shakeEventsProvider, (previous, next) {
        if (next.hasValue && next.value != previous?.value) _suggestTask();
      });
    }
    ref.listen(tasksDashboardProvider, (previous, next) {
      final dashboard = next.asData?.value;
      if (dashboard != null &&
          dashboard.season == null &&
          previous?.value?.season != null &&
          user?.isHouseholdMember == true) {
        ref.invalidate(currentUserProvider);
      }
      final status = next.asData?.value.submissionStatus;
      if (status == null ||
          identical(status, previous?.asData?.value.submissionStatus)) {
        return;
      }
      _dayTimer?.cancel();
      _dayTimer = Timer(
        status.resetsAfter.isNegative ? Duration.zero : status.resetsAfter,
        () {
          if (mounted) ref.invalidate(tasksDashboardProvider);
        },
      );
    });
    final name = ref.watch(accountNameProvider) ?? '';

    return Scaffold(
      appBar: AppPageBar(
        subtitle: 'CASA EN JUEGO',
        title: '¡Hola, $name!',
        trailing: const AccountMenu(),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
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
                        ? _StatusCard(
                            icon: Icons.event_busy_outlined,
                            title: 'No hay un ciclo activo',
                            message: 'Si el ciclo terminó, actualiza tu membresía para volver a Perfil.',
                            action: FilledButton(
                              onPressed: () =>
                                  ref.invalidate(currentUserProvider),
                              child: const Text('Actualizar membresía'),
                            ),
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
    final shake =
        ModalRoute.of(context)?.isCurrent == true &&
            data.availableForSuggestion.isNotEmpty
        ? ref.watch(shakeEventsProvider)
        : null;
    final pending = data.pendingFor(userId);
    final points = data.approvedPointsFor(userId);
    final position = data.positionFor(userId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          data.season!.name,
          style: TextStyle(color: context.appColors.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.appColors.primaryContainer,
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
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: context.appColors.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: ' puntos',
                            style: TextStyle(
                              color: context.appColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'APROBADOS',
                      style: TextStyle(
                        color: context.appColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      position == null
                          ? 'Tu próxima tarea puede sumar. ¡Vamos!'
                          : 'Vas en $position.º lugar. ¡Sigue así!',
                      style: TextStyle(
                        color: context.appColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.emoji_events_outlined,
                size: 38,
                color: context.appColors.primary,
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
        if (data.availableForSuggestion.isNotEmpty) ...[
          Text(
            shake?.hasError == true
                ? 'Agitar no está disponible. Puedes elegir una tarea de la lista.'
                : 'Agita el celular para recibir una sugerencia.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.appColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
        ],
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
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: data.submissionStatus?.isBlocked(task.id) == true
                      ? null
                      : () => _confirmTask(task, data.season!.id),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                    child: Row(
                      children: [
                        TaskIcon(iconName: task.iconName),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.name),
                              if (task.isDailyLimited)
                                Text(
                                  data.submissionStatus?.isBlocked(task.id) ==
                                          true
                                      ? 'Ya enviada hoy · Disponible mañana'
                                      : 'Una vez al día',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.appColors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+${task.points}',
                          style: TextStyle(color: context.appColors.primary),
                        ),
                        IconButton(
                          tooltip: 'Registrar ${task.name}',
                          onPressed:
                              data.submissionStatus?.isBlocked(task.id) == true
                              ? null
                              : () => _confirmTask(task, data.season!.id),
                          icon: Icon(
                            data.submissionStatus?.isBlocked(task.id) == true
                                ? Icons.check_circle_outline
                                : Icons.add_circle_outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
        color: context.statusColors.pendingContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: context.statusColors.pending, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${logs.length} ${logs.length == 1 ? 'tarea' : 'tareas'} en revisión · +$points pts',
                  style: TextStyle(
                    color: context.statusColors.pending,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  logs.length == 1
                      ? '${logs.first.taskName} · Aún no suma'
                      : 'Aún no suman al ranking',
                  style: TextStyle(
                    color: context.statusColors.pending,
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
          Icon(icon, size: 36, color: context.appColors.primary),
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
            style: TextStyle(
              color: context.appColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
