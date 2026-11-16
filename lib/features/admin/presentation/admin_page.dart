import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../models/admin_dashboard.dart';
import '../models/admin_failure.dart';
import '../providers/admin_providers.dart';
import 'widgets/admin_scaffold.dart';
import 'widgets/close_season_sheet.dart';
import 'widgets/closed_cycle_card.dart';
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

  Widget _buildInvitation(String seasonId) {
    final codeProvider = adminInviteCodeProvider(seasonId);
    return Card(
      margin: EdgeInsets.zero,
      child: ref
          .watch(codeProvider)
          .when(
            loading: () => const ListTile(title: Text('Cargando código…')),
            error: (error, stack) => ListTile(
              title: const Text('No se pudo cargar el código'),
              trailing: TextButton(
                onPressed: () => ref.invalidate(codeProvider),
                child: const Text('Reintentar'),
              ),
            ),
            data: (code) => ListTile(
              title: const Text('Código de invitación'),
              subtitle: SelectableText(code),
              trailing: IconButton(
                tooltip: 'Copiar código',
                icon: const Icon(Icons.copy_outlined),
                onPressed: () async {
                  String message;
                  try {
                    await Clipboard.setData(ClipboardData(text: code));
                    message = 'Código copiado.';
                  } catch (_) {
                    message = 'Selecciona el código para copiarlo.';
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(message)));
                },
              ),
            ),
          ),
    );
  }

  Future<void> _createCycle({required bool hasHistory}) async {
    final userId = ref.read(currentUserProvider).asData?.value?.id;
    if (userId == null) return;
    final draft = await showDialog<CycleDraft>(
      context: context,
      builder: (context) => CycleFormDialog(
        title: hasHistory ? 'Crear siguiente ciclo' : 'Crear ciclo',
      ),
    );
    if (!mounted ||
        draft == null ||
        ref.read(currentUserProvider).asData?.value?.id != userId) {
      return;
    }
    await ref
        .read(profileProvider.notifier)
        .createFirstCycle(draft.name, draft.plannedEndDate);
  }

  Widget _buildFirstCycle({required bool refreshingMembership}) {
    final profile = ref.watch(profileProvider);
    final latest = ref.watch(closedCyclesProvider).asData?.value.firstOrNull;
    final isBusy =
        refreshingMembership ||
        profile.isLoading ||
        (profile.value?.isSaving ?? false);
    return AdminScaffold(
      title: latest == null ? 'Tu primer ciclo' : 'Un nuevo comienzo',
      isBusy: isBusy,
      showNavigationBar: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (latest != null) ...[
            ref
                .watch(closedCycleProvider(latest.id))
                .when(
                  data: (summary) => ClosedCycleCard(summary: summary),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => AdminLoadError(
                    message: AdminFailure.messageFor(error),
                    onRetry: () =>
                        ref.invalidate(closedCycleProvider(latest.id)),
                  ),
                ),
            const SizedBox(height: 20),
          ],
          if (profile.hasError)
            AdminLoadError(
              message: 'No pudimos cargar tu perfil.',
              onRetry: () => ref.invalidate(profileProvider),
            )
          else
            FilledButton.icon(
              onPressed: isBusy
                  ? null
                  : () => _createCycle(hasHistory: latest != null),
              icon: const Icon(Icons.add),
              label: Text(
                isBusy
                    ? 'Preparando…'
                    : latest == null
                    ? 'Crear ciclo'
                    : 'Crear siguiente ciclo',
              ),
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
              data: (data) => data.active == null
                  ? AdminLoadError(
                      message:
                          'No hay un ciclo activo. Actualiza tu membresía.',
                      onRetry: () => ref.invalidate(currentUserProvider),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ActiveSeasonCard(summary: data.active!),
                        const SizedBox(height: 20),
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: Icon(
                              Icons.checklist,
                              color: context.appColors.primary,
                            ),
                            title: const Text('Gestionar tareas'),
                            subtitle: const Text('Catálogo del ciclo y puntos'),
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
                        _buildInvitation(data.active!.season.id),
                        if (data.active != null) ...[
                          const SizedBox(height: 24),
                          FilledButton.tonalIcon(
                            onPressed: action.isBusy
                                ? null
                                : () async {
                                    ref
                                        .read(adminActionProvider.notifier)
                                        .clearError();
                                    final closed =
                                        await showModalBottomSheet<bool>(
                                          context: context,
                                          isScrollControlled: true,
                                          isDismissible: false,
                                          enableDrag: false,
                                          showDragHandle: false,
                                          builder: (context) =>
                                              CloseSeasonSheet(
                                                summary: data.active!,
                                              ),
                                        );
                                    if (context.mounted && closed == true) {
                                      ref.invalidate(currentUserProvider);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
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
