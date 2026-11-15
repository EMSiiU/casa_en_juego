import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/leaderboard_data.dart';

String positionLabel(int? position) => position == null
    ? 'Sin puntos'
    : position == 1
    ? '1.er lugar'
    : '$position.º lugar';

class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({
    super.key,
    required this.standings,
    required this.currentUserId,
  });
  final List<LeaderboardStanding> standings;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final top = standings
        .where((standing) => standing.points > 0)
        .take(3)
        .toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final order = top.length == 1
        ? [0]
        : top.length == 2
        ? [1, 0]
        : [1, 0, 2];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final index in order)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _PodiumPerson(
                standing: top[index],
                isCurrent: top[index].member.id == currentUserId,
                isTied:
                    standings
                        .where(
                          (standing) =>
                              standing.position == top[index].position,
                        )
                        .length >
                    1,
              ),
            ),
          ),
      ],
    );
  }
}

class _PodiumPerson extends StatelessWidget {
  const _PodiumPerson({
    required this.standing,
    required this.isCurrent,
    required this.isTied,
  });
  final LeaderboardStanding standing;
  final bool isCurrent;
  final bool isTied;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (standing.position == 1) ...[
        Icon(
          Icons.workspace_premium_outlined,
          color: context.statusColors.pending,
          size: 24,
        ),
        const SizedBox(height: 8),
      ],
      CircleAvatar(
        radius: standing.position == 1 ? 26 : 22,
        backgroundColor: context.appColors.primaryContainer,
        child: Text(
          standing.member.name.characters.take(2).toString().toUpperCase(),
          style: TextStyle(
            color: context.appColors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        '${standing.member.name}${isCurrent ? ' · Tú' : ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        constraints: BoxConstraints(
          minHeight: standing.position == 1
              ? 106
              : standing.position == 2
              ? 80
              : 64,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: standing.position == 1
              ? context.appColors.primaryContainer
              : context.appColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${standing.points}',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isCurrent
                    ? context.appColors.primary
                    : context.appColors.onSurface,
              ),
            ),
            Text(
              positionLabel(standing.position),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appColors.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            if (isTied)
              Text(
                'Empate',
                style: TextStyle(
                  color: context.appColors.primary,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
