import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../activity/presentation/activity_date_formatter.dart';
import '../../../tasks/presentation/widgets/task_icon.dart';
import '../../models/review_decision.dart';
import '../../models/review_request.dart';

class ReviewRequestCard extends StatelessWidget {
  const ReviewRequestCard({
    super.key,
    required this.request,
    required this.disabled,
    required this.isProcessing,
    required this.onDecision,
  });
  final ReviewRequest request;
  final bool disabled;
  final bool isProcessing;
  final ValueChanged<ReviewDecision> onDecision;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF39334F),
                child: Text(
                  request.requesterName.characters
                      .take(2)
                      .toString()
                      .toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.requesterName),
                    const SizedBox(height: 3),
                    const Text(
                      'Solicita tu revisión',
                      style: TextStyle(color: Color(0xFFB8B9C9), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF423B2F),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Pendiente',
                  style: TextStyle(color: Color(0xFFF2C978), fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TaskIcon(iconName: request.iconName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.taskName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '+${request.pointsSnapshot} puntos si la apruebas',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            ActivityDateFormatter.format(request.requestedAt),
            style: const TextStyle(color: Color(0xFFB8B9C9), fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            request.seasonName,
            style: const TextStyle(color: AppTheme.secondaryText, fontSize: 11),
          ),
          const SizedBox(height: 16),
          if (isProcessing)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Guardando decisión…'),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: disabled
                      ? null
                      : () => onDecision(ReviewDecision.rejected),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Rechazar'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF323444),
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: disabled
                      ? null
                      : () => onDecision(ReviewDecision.approved),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Aprobar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
