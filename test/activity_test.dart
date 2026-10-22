import 'dart:async';

import 'package:casa_en_juego/core/constants/task_log_status.dart';
import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/features/activity/models/activity_entry.dart';
import 'package:casa_en_juego/features/activity/models/activity_failure.dart';
import 'package:casa_en_juego/features/activity/models/activity_filter.dart';
import 'package:casa_en_juego/features/activity/models/activity_page_state.dart';
import 'package:casa_en_juego/features/activity/presentation/activity_date_formatter.dart';
import 'package:casa_en_juego/features/activity/presentation/activity_page.dart';
import 'package:casa_en_juego/features/activity/providers/activity_providers.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_activity_repository.dart';
import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show testUser;

Future<ProviderContainer> activityContainer(
  FakeActivityRepository repository,
) async {
  final container = ProviderContainer.test(
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(testUser)),
      activityRepositoryProvider.overrideWithValue(repository),
    ],
  );
  container.listen(currentUserProvider, (_, _) {});
  await container.read(currentUserProvider.future);
  container.listen(activityProvider, (_, _) {});
  await container.read(activityProvider.future);
  return container;
}

Future<ProviderContainer> startActivity(
  WidgetTester tester,
  FakeActivityRepository repository, {
  bool submitted = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(testUser)),
        activityRepositoryProvider.overrideWithValue(repository),
        tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
      ],
      child: const CasaEnJuegoApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CasaEnJuegoApp)),
  );
  container
      .read(appRouterProvider)
      .go(submitted ? '/tasks/activity?submitted=true' : '/tasks/activity');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  test('Pending and rejected requests do not award points', () {
    expect(activityEntry().awardedPoints, 0);
    expect(activityEntry(status: TaskLogStatus.rejected).awardedPoints, 0);
    expect(activityEntry(status: TaskLogStatus.approved).awardedPoints, 8);
    final entry = ActivityEntry.fromJson({
      'id': 'id',
      'user_id': 'member-id',
      'status': 'pending',
      'points_snapshot': 3,
      'requested_at': '2026-10-22T15:42:18Z',
      'resolved_at': null,
      'tasks': {'name': 'Barrer el cuarto'},
      'seasons': {'name': 'Octubre 2026', 'status': 'closed'},
      'reviewer': null,
    });
    expect(entry.isSeasonClosed, isTrue);
    expect(entry.reviewerName, isNull);
  });

  test(
    'Dates are displayed in the fixed UTC-5 zone, including date rollover',
    () {
      expect(
        ActivityDateFormatter.format(DateTime.utc(2026, 10, 22, 15, 42, 18)),
        '22 oct 2026 · 10:42:18',
      );
      expect(
        ActivityDateFormatter.format(DateTime.utc(2026, 1, 1, 2)),
        '31 dic 2025 · 21:00:00',
      );
    },
  );

  test(
    'Pagination retains entries after an error and permits retrying',
    () async {
      final repository = FakeActivityRepository()
        ..entries = List.generate(
          23,
          (index) => activityEntry(id: 'entry-$index'),
        );
      final container = await activityContainer(repository);
      expect(container.read(activityProvider).requireValue.entries.length, 20);
      repository.loadMoreError = const ActivityFailure('Sin conexión');
      await container.read(activityProvider.notifier).loadMore();
      expect(container.read(activityProvider).requireValue.entries.length, 20);
      expect(
        container.read(activityProvider).requireValue.loadMoreError,
        isNotNull,
      );
      repository.loadMoreError = null;
      await container.read(activityProvider.notifier).loadMore();
      expect(container.read(activityProvider).requireValue.entries.length, 23);
      expect(container.read(activityProvider).requireValue.hasMore, isFalse);
      expect(
        repository.calls.every((call) => call.userId == testUser.id),
        isTrue,
      );
    },
  );

  test('A late page does not overwrite a newly selected filter', () async {
    final repository = FakeActivityRepository()
      ..entries = List.generate(
        23,
        (index) => activityEntry(id: 'entry-$index'),
      )
      ..pendingPage = Completer<ActivityPageState>();
    final container = await activityContainer(repository);
    final pending = container.read(activityProvider.notifier).loadMore();
    await container.read(activityProvider.notifier).loadMore();
    expect(repository.calls.where((call) => call.offset > 0).length, 1);
    container
        .read(activityFilterProvider.notifier)
        .select(ActivityFilter.rejected);
    await container.read(activityProvider.future);
    repository.pendingPage!.complete(
      ActivityPageState(entries: [activityEntry(id: 'late')], hasMore: false),
    );
    await pending;
    expect(container.read(activityProvider).requireValue.entries, isEmpty);
  });

  testWidgets('Filters show own requests and their resolution details', (
    tester,
  ) async {
    final repository = FakeActivityRepository()
      ..entries.add(activityEntry(id: 'foreign', userId: 'other-user'));
    await startActivity(tester, repository);
    expect(find.text('Mi actividad'), findsOneWidget);
    expect(find.text('Barrer el cuarto'), findsOneWidget);
    await tester.tap(find.text('Aprobadas'));
    await tester.pumpAndSettle();
    expect(find.text('Limpiar el baño'), findsOneWidget);
    expect(find.text('Barrer el cuarto'), findsNothing);
    expect(find.text('Aprobó Luis · 22 oct 2026 · 11:00:00'), findsOneWidget);
    await tester.tap(find.text('Rechazadas'));
    await tester.pumpAndSettle();
    expect(find.text('0 pts'), findsOneWidget);
    expect(find.text('Sacar la basura'), findsOneWidget);
  });

  testWidgets(
    'Closed cycles preserve pending history without claiming it is awaiting review',
    (tester) async {
      final repository = FakeActivityRepository()
        ..entries = [activityEntry(closed: true)];
      await startActivity(tester, repository);
      expect(find.text('Septiembre 2026'), findsOneWidget);
      expect(
        find.text('Ciclo finalizado · Solicitud sin resolver'),
        findsOneWidget,
      );
      expect(find.text('Esperando a otro miembro'), findsNothing);
    },
  );

  testWidgets('Empty states and retryable failures are visible', (
    tester,
  ) async {
    final repository = FakeActivityRepository()
      ..loadError = const ActivityFailure('Error de prueba');
    await startActivity(tester, repository);
    expect(find.text('Error de prueba'), findsOneWidget);
    repository.loadError = null;
    repository.entries = [];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no has registrado tareas'), findsOneWidget);
    await tester.tap(find.text('Pendientes'));
    await tester.pumpAndSettle();
    expect(find.text('No tienes solicitudes pendientes'), findsOneWidget);
  });

  testWidgets('Tasks links open activity and back returns to tasks', (
    tester,
  ) async {
    final repository = FakeActivityRepository();
    await startActivity(tester, repository, submitted: true);
    expect(
      find.text(
        'Enviada a revisión. La decisión aparecerá aquí cuando se resuelva.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Volver a tareas'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityPage), findsNothing);
    await tester.ensureVisible(find.text('Mi actividad →'));
    await tester.tap(find.text('Mi actividad →'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityPage), findsOneWidget);
  });

  testWidgets('Activity fits a small mobile screen with scrollable filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await startActivity(tester, FakeActivityRepository());
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rechazadas'));
    await tester.pumpAndSettle();
    expect(find.text('Sacar la basura'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
