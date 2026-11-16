import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_page_bar.dart';
import '../models/admin_failure.dart';
import '../providers/admin_providers.dart';
import 'widgets/admin_scaffold.dart';
import 'widgets/closed_cycle_card.dart';
import '../../tasks/presentation/widgets/task_icon.dart';

class CycleHistoryPage extends ConsumerWidget {
  const CycleHistoryPage({super.key, this.cycleId});

  final String? cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = cycleId;
    final history = id == null
        ? ref
              .watch(closedCyclesProvider)
              .when(
                data: (cycles) => cycles.isEmpty
                    ? const Text('Aún no tienes ciclos cerrados.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final cycle in cycles)
                            ListTile(
                              title: Text(cycle.name),
                              subtitle: cycle.endDate == null
                                  ? null
                                  : Text(
                                      MaterialLocalizations.of(context)
                                          .formatShortDate(
                                            cycle.endDate!.toLocal(),
                                          ),
                                    ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.pushNamed(
                                'closedCycle',
                                pathParameters: {'cycleId': cycle.id},
                              ),
                            ),
                        ],
                      ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => AdminLoadError(
                  message: AdminFailure.messageFor(error),
                  onRetry: () => ref.invalidate(closedCyclesProvider),
                ),
              )
        : ref
              .watch(closedCycleProvider(id))
              .when(
                data: (summary) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClosedCycleCard(summary: summary),
                    const SizedBox(height: 20),
                    Text(
                      'Catálogo del ciclo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (summary.archivedCatalog.isEmpty)
                      const Text('Este ciclo no tenía tareas.'),
                    for (final task in summary.archivedCatalog)
                      ListTile(
                        leading: TaskIcon(iconName: task.iconName),
                        title: Text(task.name),
                        subtitle: Text(
                          '${task.points} pts · '
                          '${task.isDailyLimited ? 'Una vez al día' : 'Repetible'}'
                          '${task.isActive ? '' : ' · Inactiva'}',
                        ),
                      ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => AdminLoadError(
                  message: AdminFailure.messageFor(error),
                  onRetry: () => ref.invalidate(closedCycleProvider(id)),
                ),
              );
    return Scaffold(
      appBar: AppPageBar(
        title: id == null ? 'Historial de ciclos' : 'Resultado del ciclo',
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(id == null ? 'profile' : 'cycleHistory'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [history],
            ),
          ),
        ),
      ),
    );
  }
}
