import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';

import 'support/fake_reviews_repository.dart';

import 'dart:async';

import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/tasks/models/task_failure.dart';
import 'package:casa_en_juego/features/tasks/models/task_log.dart';
import 'package:casa_en_juego/features/tasks/models/tasks_dashboard.dart';
import 'package:casa_en_juego/features/tasks/presentation/tasks_page.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show testUser;

Future<ProviderContainer> startTasks(
  WidgetTester tester,
  FakeTasksRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reviewsRepositoryProvider.overrideWithValue(FakeReviewsRepository()),
        currentUserProvider.overrideWith((ref) => Stream.value(testUser)),
        tasksRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const TasksPage()),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(TasksPage)));
}

Future<void> openConfirmation(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Barrer el cuarto'),
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Registrar Barrer el cuarto'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('A cycle closed during confirmation prevents submission', (
    tester,
  ) async {
    final repository = FakeTasksRepository();
    final container = await startTasks(tester, repository);
    await openConfirmation(tester);
    repository.dashboard = TasksDashboard(season: null, tasks: [], logs: []);
    await container.refresh(tasksDashboardProvider.future);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enviar a revisión'));
    await tester.tap(find.text('Enviar a revisión'));
    await tester.pumpAndSettle();
    expect(repository.submitCalls, 0);
    expect(
      find.text(
        'El ciclo o la tarea ya no están disponibles. Actualiza el inicio.',
      ),
      findsOneWidget,
    );
  });

  test(
    'Only approved snapshots from the current season count; ties share rank',
    () {
      final dashboard = TasksDashboard(
        season: testSeason,
        tasks: [testTask],
        logs: [
          testLog(status: TaskLogStatus.approved, points: 8),
          testLog(id: 'pending', points: 50),
          testLog(id: 'rejected', status: TaskLogStatus.rejected, points: 50),
          testLog(
            id: 'old',
            seasonId: 'old-season',
            status: TaskLogStatus.approved,
            points: 100,
          ),
          testLog(
            id: 'other',
            userId: 'other',
            status: TaskLogStatus.approved,
            points: 8,
          ),
          testLog(
            id: 'leader',
            userId: 'leader',
            status: TaskLogStatus.approved,
            points: 12,
          ),
        ],
      );
      expect(dashboard.approvedPointsFor('member-id'), 8);
      expect(dashboard.pendingFor('member-id').length, 1);
      expect(dashboard.positionFor('member-id'), 2);
      expect(dashboard.positionFor('other'), 2);
      expect(dashboard.positionFor('leader'), 1);
      expect(dashboard.positionFor('new-member'), isNull);
    },
  );

  testWidgets('No active season prevents task submission', (tester) async {
    final repository = FakeTasksRepository()
      ..dashboard = TasksDashboard(season: null, tasks: [testTask], logs: []);
    await startTasks(tester, repository);
    expect(find.text('No hay un ciclo activo'), findsOneWidget);
    expect(find.byTooltip('Registrar Barrer el cuarto'), findsNothing);
    expect(repository.submitCalls, 0);
  });

  testWidgets('Empty catalogs explain the absence of tasks', (tester) async {
    final repository = FakeTasksRepository()
      ..dashboard = TasksDashboard(season: testSeason, tasks: [], logs: []);
    await startTasks(tester, repository);
    expect(find.text('Aún no hay tareas disponibles'), findsOneWidget);
  });

  testWidgets('Load failures can be retried', (tester) async {
    final repository = FakeTasksRepository()
      ..loadError = const TaskFailure('Sin conexión');
    await startTasks(tester, repository);
    expect(find.text('Sin conexión'), findsOneWidget);
    repository.loadError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Barrer el cuarto'), findsOneWidget);
  });

  testWidgets('Cancel does not create a request', (tester) async {
    final repository = FakeTasksRepository();
    await startTasks(tester, repository);
    await openConfirmation(tester);
    expect(
      find.text('¿Enviar Barrer el cuarto para revisión?'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.submitCalls, 0);
  });

  testWidgets(
    'Submission is serialized and increases pending requests without points',
    (tester) async {
      final repository = FakeTasksRepository()
        ..pendingSubmission = Completer<void>();
      final container = await startTasks(tester, repository);
      await openConfirmation(tester);
      await tester.ensureVisible(find.text('Enviar a revisión'));
      await tester.tap(find.text('Enviar a revisión'));
      await tester.pump();
      expect(find.text('Enviando…'), findsOneWidget);
      final duplicate = await container
          .read(taskSubmissionProvider.notifier)
          .submit(taskId: testTask.id, seasonId: testSeason.id);
      expect(duplicate, isFalse);
      expect(repository.submitCalls, 1);
      repository.pendingSubmission!.complete();
      await tester.pumpAndSettle();
      expect(repository.submittedUserId, testUser.id);
      expect(repository.submittedTaskId, testTask.id);
      expect(repository.submittedSeasonId, testSeason.id);
      expect(find.text('1 tarea en revisión · +3 pts'), findsOneWidget);
      expect(
        container
            .read(tasksDashboardProvider)
            .requireValue
            .approvedPointsFor(testUser.id),
        0,
      );
      expect(
        find.text('¿Enviar Barrer el cuarto para revisión?'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Rejected submissions show an error and do not add pending requests',
    (tester) async {
      final repository = FakeTasksRepository()
        ..submitError = const TaskFailure('El ciclo terminó.');
      await startTasks(tester, repository);
      await openConfirmation(tester);
      await tester.ensureVisible(find.text('Enviar a revisión'));
      await tester.tap(find.text('Enviar a revisión'));
      await tester.pumpAndSettle();
      expect(find.text('El ciclo terminó.'), findsOneWidget);
      expect(repository.dashboard.pendingFor(testUser.id), isEmpty);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Enviar a revisión'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Volver al inicio'));
      await tester.tap(find.text('Volver al inicio'));
      await tester.pumpAndSettle();
      await openConfirmation(tester);
      expect(find.text('El ciclo terminó.'), findsNothing);
    },
  );

  testWidgets(
    'Small mobile screens allow scrolling to a task and confirming it',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeTasksRepository();
      await startTasks(tester, repository);
      await openConfirmation(tester);
      await tester.ensureVisible(find.text('Enviar a revisión'));
      expect(tester.takeException(), isNull);
    },
  );
}
