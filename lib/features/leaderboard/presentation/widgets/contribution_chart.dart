import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/leaderboard_data.dart';

class ContributionChart extends StatelessWidget {
  const ContributionChart({
    super.key,
    required this.standings,
    required this.currentUserId,
    required this.totalPoints,
  });
  final List<LeaderboardStanding> standings;
  final String currentUserId;
  final int totalPoints;

  @override
  Widget build(BuildContext context) {
    final maxPoints = standings.isEmpty || standings.first.points == 0
        ? 1.0
        : standings.first.points.toDouble();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Puntos por persona', style: TextStyle(fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              'Solo tareas aprobadas · Total familiar: $totalPoints pts',
              style: const TextStyle(fontSize: 11, color: Color(0xFFB8B9C9)),
            ),
            const SizedBox(height: 16),
            for (final standing in standings)
              Semantics(
                label:
                    '${standing.member.name}, ${standing.points} puntos aprobados',
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            standing.member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB8B9C9),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 14,
                            child: BarChart(
                              BarChartData(
                                rotationQuarterTurns: 1,
                                minY: 0,
                                maxY: maxPoints,
                                titlesData: const FlTitlesData(show: false),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barTouchData: BarTouchData(enabled: false),
                                barGroups: [
                                  BarChartGroupData(
                                    x: 0,
                                    barRods: [
                                      BarChartRodData(
                                        toY: standing.points.toDouble(),
                                        width: 10,
                                        color:
                                            standing.member.id == currentUserId
                                            ? AppTheme.primary
                                            : AppTheme.secondaryText,
                                        borderRadius: BorderRadius.circular(4),
                                        backDrawRodData:
                                            BackgroundBarChartRodData(
                                              show: true,
                                              toY: maxPoints,
                                              color: const Color(0xFF333543),
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              duration: Duration.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 38,
                          child: Text(
                            '${standing.points}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
