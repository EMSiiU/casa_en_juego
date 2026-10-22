import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/household_task.dart';
import '../../models/task_failure.dart';
import '../../providers/tasks_providers.dart';
import 'task_icon.dart';

class TaskSubmissionSheet extends ConsumerWidget {
  const TaskSubmissionSheet({
    super.key,
    required this.task,
    required this.seasonId,
  });
  final HouseholdTask task;
  final String seasonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(taskSubmissionProvider);
    return PopScope(
      canPop: !action.isLoading,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryText,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  TaskIcon(iconName: task.iconName, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '+${task.points} puntos pendientes',
                      style: const TextStyle(color: Color(0xFFF2C978)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '¿Enviar ${task.name} para revisión?',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Otro miembro debe aprobar tu tarea. Tu solicitud quedará pendiente de revisión.',
                style: TextStyle(color: Color(0xFFB8B9C9), height: 1.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Estos ${task.points} puntos no se suman hasta que la solicitud sea aprobada.',
                style: const TextStyle(color: Color(0xFFF2C978)),
              ),
              if (action.hasError) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    TaskFailure.messageFor(action.error!, submitting: true),
                    style: const TextStyle(color: Color(0xFFF3A69B)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: action.isLoading || action.hasError
                    ? null
                    : () async {
                        final success = await ref
                            .read(taskSubmissionProvider.notifier)
                            .submit(taskId: task.id, seasonId: seasonId);
                        if (context.mounted && success) {
                          Navigator.of(context).pop(true);
                        }
                      },
                icon: action.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined, size: 20),
                label: Text(
                  action.isLoading ? 'Enviando…' : 'Enviar a revisión',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: action.isLoading
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text(
                  action.hasError ? 'Volver al inicio' : 'Cancelar',
                  style: const TextStyle(color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
