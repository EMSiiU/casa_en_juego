import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../activity/presentation/activity_date_formatter.dart';
import '../../models/admin_dashboard.dart';

class ClosedCycleCard extends StatelessWidget {
  const ClosedCycleCard({super.key, required this.summary});
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
