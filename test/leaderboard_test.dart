import 'package:casa_en_juego/core/constants/task_log_status.dart';
import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/leaderboard/models/leaderboard_data.dart';
import 'package:casa_en_juego/features/leaderboard/models/leaderboard_failure.dart';
import 'package:casa_en_juego/features/leaderboard/presentation/leaderboard_page.dart';
import 'package:casa_en_juego/features/leaderboard/presentation/widgets/leaderboard_podium.dart';
import 'package:casa_en_juego/features/leaderboard/providers/leaderboard_providers.dart';
import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/main.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_leaderboard_repository.dart';
import 'support/fake_reviews_repository.dart';
import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show testUser;

Future<ProviderContainer> startLeaderboard(
  WidgetTester tester,
  FakeLeaderboardRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(testUser)),
        leaderboardRepositoryProvider.overrideWithValue(repository),
        tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
        reviewsRepositoryProvider.overrideWithValue(FakeReviewsRepository()),
      ],
      child: const CasaEnJuegoApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CasaEnJuegoApp)),
  );
  container.read(appRouterProvider).go('/leaderboard');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  test('Ranking excludes unapproved and old-cycle scores, preserves snapshots and includes zero-point members', () {
    final data = LeaderboardData(
      season: testSeason,
      members: leaderboardMembers,
      scores: [
        leaderboardScore(points: 8),
        leaderboardScore(id: 'repeat', points: 5),
        leaderboardScore(
          id: 'pending',
          points: 100,
          status: TaskLogStatus.pending,
        ),
        leaderboardScore(
          id: 'rejected',
          points: 100,
          status: TaskLogStatus.rejected,
        ),
        leaderboardScore(id: 'old', points: 100, seasonId: 'old-cycle'),
      ],
    );
    expect(data.totalPoints, 13);
    expect(data.standingFor(testUser.id)!.position, 1);
    expect(data.standings.length, 4);
    expect(data.standingFor('luis-id')!.points, 0);
    expect(data.standingFor('luis-id')!.position, isNull);
    expect(data.bestTasksFor(testUser.id).single.points, 13);
    expect(data.bestTasksFor(testUser.id).single.completedCount, 2);
  });

  test('Ties share positions and duplicate rows do not double the score', () {
    final score = leaderboardScore(points: 8);
    final data = LeaderboardData(
      season: testSeason,
      members: leaderboardMembers,
      scores: [
        score,
        score,
        leaderboardScore(id: 'luis', userId: 'luis-id', points: 8),
        leaderboardScore(id: 'marta', userId: 'marta-id', points: 5),
      ],
    );
    expect(data.totalPoints, 21);
    expect(data.standingFor(testUser.id)!.position, 1);
    expect(data.standingFor('luis-id')!.position, 1);
    expect(data.standingFor('marta-id')!.position, 3);
  });

  testWidgets('Ranking shows podium, team total and horizontal bars', (
    tester,
  ) async {
    await startLeaderboard(tester, FakeLeaderboardRepository());
    expect(find.byType(LeaderboardPodium), findsOneWidget);
    expect(find.text('Ana · Tú'), findsOneWidget);
    await tester.ensureVisible(find.text('Puntos por persona'));
    await tester.pumpAndSettle();
    expect(
      find.text('Solo tareas aprobadas · Total familiar: 123 pts'),
      findsOneWidget,
    );
    expect(find.byType(BarChart), findsNWidgets(4));
    expect(
      tester
          .widgetList<BarChart>(find.byType(BarChart))
          .every((chart) => chart.data.rotationQuarterTurns == 1),
      isTrue,
    );
    await tester.ensureVisible(find.text('Tu aporte al equipo'));
    expect(find.text('42 de 123'), findsOneWidget);
  });

  testWidgets(
    'Zero-point seasons show no winners and keep chart limits valid',
    (tester) async {
      final repository = FakeLeaderboardRepository()
        ..data = LeaderboardData(
          season: testSeason,
          members: leaderboardMembers,
          scores: [],
        );
      await startLeaderboard(tester, repository);
      expect(find.text('Aún no hay puntos aprobados'), findsOneWidget);
      expect(find.byType(LeaderboardPodium), findsNothing);
      await tester.ensureVisible(find.text('Puntos por persona'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<BarChart>(find.byType(BarChart))
            .every((chart) => chart.data.maxY == 1),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Inactive seasons and empty family states are explicit', (
    tester,
  ) async {
    final repository = FakeLeaderboardRepository()
      ..data = LeaderboardData(season: null, members: [], scores: []);
    final container = await startLeaderboard(tester, repository);
    expect(find.text('No hay un ciclo activo'), findsOneWidget);
    repository.data = LeaderboardData(
      season: testSeason,
      members: [],
      scores: [],
    );
    container.invalidate(leaderboardProvider);
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay participantes'), findsOneWidget);
  });

  testWidgets('Loading failures can be retried', (tester) async {
    final repository = FakeLeaderboardRepository()
      ..error = const LeaderboardFailure('Error de prueba');
    await startLeaderboard(tester, repository);
    expect(find.text('Error de prueba'), findsOneWidget);
    repository.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byType(LeaderboardPodium), findsOneWidget);
  });

  testWidgets(
    'Podium supports one member on a small screen and ranking navigation works',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeLeaderboardRepository()
        ..data = LeaderboardData(
          season: testSeason,
          members: [leaderboardMembers.first],
          scores: [leaderboardScore()],
        );
      await startLeaderboard(tester, repository);
      expect(find.text('Ana · Tú'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Tareas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ranking'));
      await tester.pumpAndSettle();
      expect(find.byType(LeaderboardPage), findsOneWidget);
    },
  );
}
