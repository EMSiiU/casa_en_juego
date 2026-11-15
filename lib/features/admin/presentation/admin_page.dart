import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../activity/presentation/activity_date_formatter.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../models/admin_dashboard.dart';
import '../models/admin_failure.dart';
import '../providers/admin_providers.dart';
import 'widgets/admin_scaffold.dart';
import 'widgets/close_season_sheet.dart';
import 'widgets/cycle_form_dialog.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});
  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (ref.read(currentUserProvider).asData?.value?.isAdmin == true &&
            !ref.read(adminActionProvider).isBusy) {
          ref.invalidate(adminDashboardProvider);
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (ref.read(adminActionProvider).isBusy) return;
    ref.read(adminActionProvider.notifier).clearError();
    ref.invalidate(adminDashboardProvider);
    try {
      await ref.read(adminDashboardProvider.future);
    } catch (_) {
      // La vista conserva una opción para reintentar la carga.
    }
  }

  Future<void> _createCycle({required bool first}) async {
    final userId = ref.read(currentUserProvider).asData?.value?.id;
    if (userId == null) return;
    final draft = await showDialog<CycleDraft>(
      context: context,
      builder: (context) => CycleFormDialog(
        title: first ? 'Crear ciclo' : 'Crear siguiente ciclo',
      ),
    );
    if (!mounted ||
        draft == null ||
        ref.read(currentUserProvider).asData?.value?.id != userId) {
      return;
    }
    if (first) {
      await ref
          .read(profileProvider.notifier)
          .createFirstCycle(draft.name, draft.plannedEndDate);
      return;
    }
    final started = await ref
        .read(adminActionProvider.notifier)
        .startSeason(draft.name, draft.plannedEndDate);
    if (mounted && started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          persist: false,
          content: Text('Nuevo ciclo iniciado.'),
        ),
      );
    }
  }

  Widget _buildFirstCycle({required bool refreshingMembership}) {
    final profile = ref.watch(profileProvider);
    final isBusy =
        refreshingMembership ||
        profile.isLoading ||
        (profile.value?.isSaving ?? false);
    return AdminScaffold(
      title: 'Tu primer ciclo',
      isBusy: isBusy,
      showNavigationBar: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (profile.hasError)
            AdminLoadError(
              message: 'No pudimos cargar tu perfil.',
              onRetry: () => ref.invalidate(profileProvider),
            )
          else
            FilledButton.icon(
              onPressed: isBusy ? null : () => _createCycle(first: true),
              icon: const Icon(Icons.add),
              label: Text(isBusy ? 'Preparando…' : 'Crear ciclo'),
            ),
          if (profile.value?.errorMessage case final message?) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: TextStyle(color: context.appColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentUserProvider);
    if (session.value?.isHouseholdMember == false) {
      return _buildFirstCycle(refreshingMembership: session.isLoading);
    }
    final dashboard = ref.watch(adminDashboardProvider);
    final action = ref.watch(adminActionProvider);
    final active = dashboard.asData?.value.active != null;
    return AdminScaffold(
      title: active ? 'Cuidar del equipo' : 'Un nuevo comienzo',
      subtitle: 'PANEL DE ADMINISTRADOR',
      isBusy: action.isBusy,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            dashboard.when(
              skipLoadingOnRefresh: false,
              loading: () => const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => AdminLoadError(
                message: AdminFailure.messageFor(error),
                onRetry: _refresh,
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data.active != null) ...[
                    _ActiveSeasonCard(summary: data.active!),
                    const SizedBox(height: 20),
                  ] else ...[
                    if (data.latestClosed != null) ...[
                      _ClosedSeasonCard(summary: data.latestClosed!),
                      const SizedBox(height: 20),
                    ],
                    FilledButton.icon(
                      onPressed: action.isBusy
                          ? null
                          : () => _createCycle(first: false),
                      icon: const Icon(Icons.add),
                      label: Text(
                        action.isBusy ? 'Iniciando…' : 'Crear siguiente ciclo',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const AdminInfo(
                      'Mientras no haya ciclo activo, los miembros no pueden registrar tareas.',
                    ),
                    const SizedBox(height: 20),
                  ],
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(
                        Icons.checklist,
                        color: context.appColors.primary,
                      ),
                      title: const Text('Gestionar tareas'),
                      subtitle: const Text('Catálogo del grupo y puntos'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: action.isBusy
                          ? null
                          : () {
                              ref
                                  .read(adminActionProvider.notifier)
                                  .clearError();
                              context.pushNamed('adminTasks');
                            },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Miembros del grupo',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'La incorporación de miembros por código estará disponible más adelante.',
                            style: TextStyle(
                              color: context.appColors.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (data.active != null) ...[
                    const SizedBox(height: 24),
                    FilledButton.tonalIcon(
                      onPressed: action.isBusy
                          ? null
                          : () async {
                              ref
                                  .read(adminActionProvider.notifier)
                                  .clearError();
                              final closed = await showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                isDismissible: false,
                                enableDrag: false,
                                showDragHandle: false,
                                builder: (context) =>
                                    CloseSeasonSheet(summary: data.active!),
                              );
                              if (context.mounted && closed == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    duration: Duration(seconds: 3),
                                    persist: false,
                                    content: Text(
                                      'Ciclo finalizado. Resultados conservados.',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Finalizar ciclo'),
                    ),
                    const SizedBox(height: 12),
                    AdminInfo(
                      data.active!.pendingCount > 0
                          ? 'Antes de cerrar, revisa ${data.active!.pendingCount == 1 ? 'la solicitud pendiente' : 'las ${data.active!.pendingCount} solicitudes pendientes'}. Recomendamos resolverlas primero.'
                          : 'Solo puedes iniciar otro ciclo cuando el actual haya finalizado.',
                      warning: data.active!.pendingCount > 0,
                    ),
                  ],
                  if (action.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        action.errorMessage!,
                        style: TextStyle(color: context.appColors.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveSeasonCard extends StatelessWidget {
  const _ActiveSeasonCard({required this.summary});
  final SeasonSummary summary;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TEMPORADA ACTUAL · ACTIVA',
            style: TextStyle(
              fontSize: 10,
              color: context.statusColors.approved,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            summary.season.name,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          if (summary.season.plannedEndDate case final date?) ...[
            const SizedBox(height: 6),
            Text(
              'Fin previsto · ${MaterialLocalizations.of(context).formatShortDate(date)}',
            ),
          ],
          if (summary.season.plannedDurationDays case final days?) ...[
            const SizedBox(height: 6),
            Text('Duración prevista · ${days == 1 ? '1 día' : '$days días'}'),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final metric in [
                (summary.approvedPoints, 'pts aprobados'),
                (summary.participants, 'participantes'),
                (summary.pendingCount, 'pendientes'),
              ])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${metric.$1}',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        metric.$2,
                        style: TextStyle(
                          color: context.appColors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Solo las solicitudes aprobadas suman al ranking.',
            style: TextStyle(
              color: context.appColors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ClosedSeasonCard extends StatelessWidget {
  const _ClosedSeasonCard({required this.summary});
  final SeasonSummary summary;
  @override
  Widget build(BuildContext context) {
    final results = summary.results;
    final hasPoints = summary.approvedPoints > 0;
    final tied = results.length > 1 && results[1].position == 1;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${summary.season.name} · Finalizado',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (summary.season.endDate != null)
              Text(
                'Cierre: ${ActivityDateFormatter.format(summary.season.endDate!)} (UTC−5)',
                style: TextStyle(
                  color: context.appColors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            const SizedBox(height: 16),
            if (!hasPoints)
              const Text('Sin ganador · no hubo puntos aprobados.')
            else
              for (final result in results)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Text(
                        '${result.position}.',
                        style: TextStyle(color: context.appColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(result.name),
                            if (result.position == 1)
                              Text(
                                tied
                                    ? 'Empate en primer lugar'
                                    : 'Ganador del ciclo',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                          ],
                        ),
                      ),
                      Text('${result.points} pts'),
                    ],
                  ),
                ),
            Text(
              '${summary.approvedPoints} puntos aprobados · Resultados conservados',
              style: TextStyle(
                color: context.appColors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            if (summary.pendingCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                summary.pendingCount == 1
                    ? '1 solicitud quedó sin resolver y no suma puntos.'
                    : '${summary.pendingCount} solicitudes quedaron sin resolver y no suman puntos.',
                style: TextStyle(
                  color: context.statusColors.pending,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
