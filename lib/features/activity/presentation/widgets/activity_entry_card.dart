import 'package:flutter/material.dart';

import '../../../../core/constants/task_log_status.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/activity_entry.dart';
import '../activity_date_formatter.dart';

class ActivityEntryCard extends StatelessWidget {
  const ActivityEntryCard({super.key, required this.entry});
  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (entry.status) {
      TaskLogStatus.pending => ('Pendiente', const Color(0xFFF2C978)),
      TaskLogStatus.approved => ('Aprobada', const Color(0xFF91D5C6)),
      TaskLogStatus.rejected => ('Rechazada', const Color(0xFFF3A69B)),
    };
    final pending = entry.status == TaskLogStatus.pending;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.status == TaskLogStatus.rejected
                        ? '0 pts'
                        : '+${entry.pointsSnapshot} pts',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: entry.status == TaskLogStatus.rejected
                          ? AppTheme.secondaryText
                          : color,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.taskName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Text(
              ActivityDateFormatter.format(entry.requestedAt),
              style: const TextStyle(color: Color(0xFFB8B9C9), fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              entry.seasonName,
              style: const TextStyle(
                color: AppTheme.secondaryText,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            if (pending)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    entry.isSeasonClosed
                        ? Icons.event_busy_outlined
                        : Icons.schedule,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.isSeasonClosed
                          ? 'Ciclo finalizado · Solicitud sin resolver'
                          : 'Esperando a otro miembro',
                      style: TextStyle(color: color, fontSize: 11),
                    ),
                  ),
                ],
              )
            else
              Text(
                '${entry.status == TaskLogStatus.approved ? 'Aprobó' : 'Rechazó'} ${entry.reviewerName ?? 'otro miembro'}'
                '${entry.resolvedAt == null ? '' : ' · ${ActivityDateFormatter.format(entry.resolvedAt!)}'}',
                style: const TextStyle(
                  color: Color(0xFFB8B9C9),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
