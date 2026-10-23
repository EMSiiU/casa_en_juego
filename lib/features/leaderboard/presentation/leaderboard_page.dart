import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_navigation_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../../tasks/presentation/widgets/task_icon.dart';
import '../models/leaderboard_data.dart';
import '../models/leaderboard_failure.dart';
import '../providers/leaderboard_providers.dart';
import 'widgets/contribution_chart.dart';
import 'widgets/leaderboard_podium.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(leaderboardProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(leaderboardProvider);
    try {
      await ref.read(leaderboardProvider.future);
    } catch (_) {
      // La pantalla muestra el error y permite volver a intentar.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final data = ref.watch(leaderboardProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RANKING FAMILIAR',
              style: TextStyle(fontSize: 10, color: AppTheme.primary),
            ),
            SizedBox(height: 4),
            Text(
              'El esfuerzo se nota',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF39334F),
              child: Text(
                (user?.name ?? '').characters.take(2).toString().toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  data.when(
                    skipLoadingOnRefresh: false,
                    loading: () => const SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) => _LeaderboardStatus(
                      message: LeaderboardFailure.messageFor(error),
                      action: FilledButton(
                        onPressed: _refresh,
                        child: const Text('Reintentar'),
                      ),
                    ),
                    data: (snapshot) => snapshot.season == null
                        ? const _LeaderboardStatus(
                            title: 'No hay un ciclo activo',
                            message: 'El ranking comenzará cuando el administrador inicie una nueva temporada.',
                          )
                        : _buildRanking(snapshot, user?.id ?? ''),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppNavigationBar(selectedIndex: 1),
    );
  }

  Widget _buildRanking(LeaderboardData data, String userId) {
    final standings = data.standings;
    final total = data.totalPoints;
    final current = data.standingFor(userId);
    final bestTasks = data.bestTasksFor(userId);
    final podiumIds = standings
        .where((standing) => standing.points > 0)
        .take(3)
        .map((standing) => standing.member.id)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data.season!.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF26413E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Ciclo activo',
                style: TextStyle(color: Color(0xFF91D5C6), fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (standings.isEmpty)
          const _LeaderboardStatus(
            title: 'Aún no hay participantes',
            message: 'Los miembros de la familia aparecerán aquí.',
          )
        else if (total == 0)
          const _LeaderboardStatus(
            title: 'Aún no hay puntos aprobados',
            message: 'Registra una tarea y espera la aprobación de otro miembro para empezar a sumar.',
          )
        else
          LeaderboardPodium(standings: standings, currentUserId: userId),
        const SizedBox(height: 16),
        for (final standing in standings.where(
          (standing) => !podiumIds.contains(standing.member.id),
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(
                      standing.position?.toString() ?? '—',
                      style: const TextStyle(color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${standing.member.name}${standing.member.id == userId ? ' · Tú' : ''}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${standing.points} pts'),
                  ],
                ),
              ),
            ),
          ),
        if (standings.isNotEmpty) ...[
          const SizedBox(height: 8),
          ContributionChart(
            standings: standings,
            currentUserId: userId,
            totalPoints: total,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Tu posición',
                  value: positionLabel(current?.position),
                  highlighted: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Tu aporte al equipo',
                  value: '${current?.points ?? 0} de $total',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Tus mejores tareas', style: TextStyle(fontSize: 17)),
          const SizedBox(height: 12),
          if (bestTasks.isEmpty)
            const Text(
              'Tus tareas aprobadas aparecerán aquí.',
              style: TextStyle(color: Color(0xFFB8B9C9), fontSize: 12),
            )
          else
            for (final task in bestTasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    TaskIcon(iconName: task.iconName, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.taskName,
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            '${task.completedCount} ${task.completedCount == 1 ? 'aprobada' : 'aprobadas'}',
                            style: const TextStyle(
                              color: Color(0xFFB8B9C9),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${task.points} pts',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Solo suman las tareas aprobadas del ciclo activo. Los empates comparten posición.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFB8B9C9), fontSize: 11, height: 1.5),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.highlighted = false,
  });
  final String label;
  final String value;
  final bool highlighted;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: highlighted ? const Color(0xFF39334F) : AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB8B9C9), fontSize: 11),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
      ],
    ),
  );
}

class _LeaderboardStatus extends StatelessWidget {
  const _LeaderboardStatus({required this.message, this.title, this.action});
  final String? title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 38,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 16),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
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
