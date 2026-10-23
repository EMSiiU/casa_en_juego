import 'package:casa_en_juego/features/tasks/models/household_task.dart';
import 'package:casa_en_juego/features/tasks/models/task_failure.dart';
import 'package:casa_en_juego/features/tasks/models/task_submission_status.dart';
import 'package:casa_en_juego/features/tasks/models/tasks_dashboard.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_tasks_repository.dart';
import 'tasks_test.dart' show startTasks;

const dailyTask = HouseholdTask(
  id: 'task-id',
  name: 'Barrer el cuarto',
  points: 3,
  iconName: 'broom',
  isActive: true,
  isDailyLimited: true,
);

TasksDashboard dashboard({
  required Set<String> blocked,
  Duration reset = const Duration(hours: 12),
}) => TasksDashboard(
  season: testSeason,
  tasks: [dailyTask],
  logs: [],
  submissionStatus: TaskSubmissionStatus(
    blockedTaskIds: blocked,
    resetsAfter: reset,
  ),
);

void main() {
  test('Server time controls midnight independently of device time', () {
    final status = TaskSubmissionStatus.fromJson({
      'server_now': '2026-10-23T05:59:59Z',
      'resets_at': '2026-10-23T06:00:00Z',
      'blocked_task_ids': ['task-id'],
    });
    expect(status.resetsAfter, const Duration(seconds: 1));
    expect(status.isBlocked('task-id'), isTrue);
    expect(status.isBlocked('other'), isFalse);
  });

  test(
    'Daily conflicts explain the restriction rather than connection errors',
    () {
      expect(
        TaskFailure.messageFor(
          const PostgrestException(
            message: 'TASK_DAILY_LIMIT_REACHED',
            code: 'P0001',
          ),
        ),
        contains('mañana o si se rechaza'),
      );
    },
  );

  testWidgets(
    'Blocked task disables submission and controller guards stale taps',
    (tester) async {
      final repository = FakeTasksRepository()
        ..dashboard = dashboard(blocked: {'task-id'});
      final container = await startTasks(tester, repository);
      expect(find.text('Ya enviada hoy · Disponible mañana'), findsOneWidget);
      final button = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip == 'Registrar Barrer el cuarto',
        ),
      );
      expect(button.onPressed, isNull);
      final subscription = container.listen(taskSubmissionProvider, (_, _) {});
      final sent = await container
          .read(taskSubmissionProvider.notifier)
          .submit(taskId: 'task-id', seasonId: testSeason.id);
      expect(sent, isFalse);
      expect(repository.submitCalls, 0);
      subscription.close();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Midnight reloads server status and enables the task again', (
    tester,
  ) async {
    final repository = FakeTasksRepository()
      ..dashboard = dashboard(
        blocked: {'task-id'},
        reset: const Duration(seconds: 2),
      );
    await startTasks(tester, repository);
    repository.dashboard = dashboard(blocked: {});
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Ya enviada hoy · Disponible mañana'), findsNothing);
    final button = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == 'Registrar Barrer el cuarto',
      ),
    );
    expect(button.onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
}
