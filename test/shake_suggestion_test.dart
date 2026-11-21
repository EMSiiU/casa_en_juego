import 'dart:async';

import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';
import 'package:casa_en_juego/features/tasks/models/household_task.dart';
import 'package:casa_en_juego/features/tasks/models/tasks_dashboard.dart';
import 'package:casa_en_juego/features/tasks/models/task_submission_status.dart';
import 'package:casa_en_juego/features/tasks/presentation/tasks_page.dart';
import 'package:casa_en_juego/features/tasks/providers/shake_provider.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/features/tasks/services/shake_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'support/fake_reviews_repository.dart';
import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show testUser;

Future<void> start(
  WidgetTester tester,
  FakeTasksRepository repository,
  Stream<int> shakes,
) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(testUser)),
        reviewsRepositoryProvider.overrideWithValue(FakeReviewsRepository()),
        tasksRepositoryProvider.overrideWithValue(repository),
        shakeEventsProvider.overrideWith((ref) => shakes),
      ],
      child: const MaterialApp(home: TasksPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('Stillness, ordinary movement and a single sustained impulse do not suggest', () {
    final detector = ShakeDetector();
    expect(detector.add(0, 0, 0, Duration.zero), isFalse);
    expect(detector.add(3, 2, 1, const Duration(milliseconds: 50)), isFalse);
    expect(detector.add(15, 0, 0, const Duration(milliseconds: 100)), isFalse);
    expect(detector.add(16, 0, 0, const Duration(milliseconds: 300)), isFalse);
  });

  test(
    'Two separated impulses trigger once; cooldown ignores repeated shaking',
    () {
      final detector = ShakeDetector();
      expect(detector.add(15, 0, 0, Duration.zero), isFalse);
      detector.add(0, 0, 0, const Duration(milliseconds: 50));
      expect(
        detector.add(-15, 0, 0, const Duration(milliseconds: 150)),
        isTrue,
      );
      detector.add(0, 0, 0, const Duration(milliseconds: 200));
      expect(
        detector.add(15, 0, 0, const Duration(milliseconds: 300)),
        isFalse,
      );
      detector.add(0, 0, 0, const Duration(milliseconds: 2200));
      expect(
        detector.add(15, 0, 0, const Duration(milliseconds: 2300)),
        isFalse,
      );
      detector.add(0, 0, 0, const Duration(milliseconds: 2350));
      expect(
        detector.add(-15, 0, 0, const Duration(milliseconds: 2450)),
        isTrue,
      );
    },
  );

  test('Impulses too far apart do not trigger', () {
    final detector = ShakeDetector();
    detector.add(15, 0, 0, Duration.zero);
    detector.add(0, 0, 0, const Duration(milliseconds: 100));
    expect(detector.add(15, 0, 0, const Duration(seconds: 1)), isFalse);
  });

  test(
    'Suggestion excludes inactive and daily-blocked tasks and closed cycles',
    () {
      const inactive = HouseholdTask(
        id: 'off',
        name: 'Oculta',
        points: 1,
        iconName: 'broom',
        isActive: false,
      );
      const blocked = HouseholdTask(
        id: 'blocked',
        name: 'Ya enviada',
        points: 1,
        iconName: 'broom',
        isActive: true,
        isDailyLimited: true,
      );
      final data = TasksDashboard(
        season: testSeason,
        tasks: [inactive, blocked, testTask],
        logs: [],
        submissionStatus: TaskSubmissionStatus(
          blockedTaskIds: {'blocked'},
          resetsAfter: const Duration(hours: 1),
        ),
      );
      expect(data.availableForSuggestion, [testTask]);
      expect(
        TasksDashboard(
          season: null,
          tasks: [testTask],
          logs: [],
        ).availableForSuggestion,
        isEmpty,
      );
    },
  );

  testWidgets(
    'Shake only suggests, does not submit, and does not stack dialogs',
    (tester) async {
      final events = StreamController<int>.broadcast();
      addTearDown(events.close);
      final repository = FakeTasksRepository();
      await start(tester, repository, events.stream);
      events.add(1);
      await tester.pumpAndSettle();
      expect(find.text('Tarea sugerida'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(testTask.name),
        ),
        findsOneWidget,
      );
      events.add(2);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repository.submitCalls, 0);
      expect(repository.dashboard.approvedPointsFor(testUser.id), 0);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.submitCalls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Sensor failure preserves manual task registration', (
    tester,
  ) async {
    final events = StreamController<int>.broadcast();
    addTearDown(events.close);
    final repository = FakeTasksRepository();
    await start(tester, repository, events.stream);
    events.addError(UnsupportedError('No sensor'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Agitar no está disponible'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byTooltip('Registrar Barrer el cuarto'),
      150,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Registrar Barrer el cuarto'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar a revisión'), findsOneWidget);
    expect(repository.submitCalls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('No available tasks means no sensor subscription', (
    tester,
  ) async {
    var listens = 0;
    final events = StreamController<int>.broadcast(onListen: () => listens++);
    addTearDown(events.close);
    final repository = FakeTasksRepository()
      ..dashboard = TasksDashboard(season: testSeason, tasks: [], logs: []);
    await start(tester, repository, events.stream);
    expect(listens, 0);
    expect(find.textContaining('Agita el celular'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Native readings stop in background, resume, and cancel on disposal',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var starts = 0;
      var stops = 0;
      final acceleration = StreamController<UserAccelerometerEvent>.broadcast(
        onListen: () => starts++,
        onCancel: () => stops++,
      );
      addTearDown(acceleration.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userAccelerationProvider.overrideWithValue(acceleration.stream),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              ref.watch(shakeEventsProvider);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      expect(starts, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(stops, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(starts, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(stops, 2);
    },
  );
}
