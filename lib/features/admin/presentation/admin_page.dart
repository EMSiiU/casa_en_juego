import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../activity/presentation/activity_date_formatter.dart';
import '../models/admin_dashboard.dart';
import '../models/admin_failure.dart';
import '../providers/admin_providers.dart';
import 'widgets/admin_scaffold.dart';
import 'widgets/close_season_sheet.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});
  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!ref.read(adminActionProvider).isBusy) {
          ref.invalidate(adminDashboardProvider);
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _nameController.dispose();
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

  @override
  Widget build(BuildContext context) {
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
                    const AdminInfo(
                      'No hay ninguna temporada activa. Puedes iniciar un nuevo ciclo.',
                    ),
                    const SizedBox(height: 20),
                    if (data.latestClosed != null) ...[
                      _ClosedSeasonCard(summary: data.latestClosed!),
                      const SizedBox(height: 20),
                    ],
                    Form(
                      key: _formKey,
                      child: Card(
                        margin: EdgeInsets.zero,
                        color: const Color(0xFF39334F),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Siguiente temporada',
                                style: TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameController,
                                enabled: !action.isBusy,
                                maxLength: 100,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre del ciclo',
                                  counterText: '',
                                  hintText: 'Noviembre 2026',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Escribe el nombre del ciclo.'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Todos comienzan con 0 puntos. Los ciclos anteriores quedan guardados y no se modifican.',
                                style: TextStyle(
                                  color: Color(0xFFB8B9C9),
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: action.isBusy
                                    ? null
                                    : () async {
                                        if (!_formKey.currentState!
                                            .validate()) {
                                          return;
                                        }
                                        FocusScope.of(context).unfocus();
                                        final started = await ref
                                            .read(adminActionProvider.notifier)
                                            .startSeason(_nameController.text);
                                        if (context.mounted && started) {
                                          _nameController.clear();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Nuevo ciclo iniciado.',
                                                  ),
                                                ),
                                              );
                                        }
                                      },
                                icon: const Icon(Icons.add),
                                label: Text(
                                  action.isBusy
                                      ? 'Iniciando…'
                                      : 'Iniciar nuevo ciclo',
                                ),
                              ),
                            ],
                          ),
                        ),
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
                      leading: const Icon(
                        Icons.checklist,
                        color: AppTheme.primary,
                      ),
                      title: const Text('Gestionar tareas'),
                      subtitle: const Text('Catálogo familiar y puntos'),
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
                  const Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Miembros de la familia',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Las cuentas se crean y administran fuera de la app, desde Supabase. Aquí no se registran usuarios.',
                            style: TextStyle(
                              color: Color(0xFFB8B9C9),
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
                        style: const TextStyle(color: Color(0xFFF3A69B)),
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
          const Text(
            'TEMPORADA ACTUAL · ACTIVA',
            style: TextStyle(fontSize: 10, color: Color(0xFF91D5C6)),
          ),
          const SizedBox(height: 18),
          Text(
            summary.season.name,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
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
                        style: const TextStyle(
                          color: Color(0xFFB8B9C9),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Solo las solicitudes aprobadas suman al ranking.',
            style: TextStyle(color: Color(0xFFB8B9C9), fontSize: 11),
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
  Widget build(BuildContext context) => Card(
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
              style: const TextStyle(color: Color(0xFFB8B9C9), fontSize: 11),
            ),
          const SizedBox(height: 16),
          if (summary.approvedPoints == 0)
            const Text('Sin puntos aprobados en este ciclo.')
          else
            for (final result in summary.results)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(
                      '${result.position}.',
                      style: const TextStyle(color: AppTheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(result.name)),
                    Text('${result.points} pts'),
                  ],
                ),
              ),
          Text(
            '${summary.approvedPoints} puntos aprobados · Resultados conservados',
            style: const TextStyle(color: Color(0xFFB8B9C9), fontSize: 11),
          ),
          if (summary.pendingCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              summary.pendingCount == 1
                  ? '1 solicitud quedó sin resolver y no suma puntos.'
                  : '${summary.pendingCount} solicitudes quedaron sin resolver y no suman puntos.',
              style: const TextStyle(color: Color(0xFFF2C978), fontSize: 11),
            ),
          ],
        ],
      ),
    ),
  );
}
