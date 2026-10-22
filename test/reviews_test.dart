import 'dart:async';

import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/reviews/models/review_decision.dart';
import 'package:casa_en_juego/features/reviews/models/review_failure.dart';
import 'package:casa_en_juego/features/reviews/presentation/reviews_page.dart';
import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_reviews_repository.dart';
import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show testUser;

Future<ProviderContainer> startReviews(
  WidgetTester tester,
  FakeReviewsRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(testUser)),
        reviewsRepositoryProvider.overrideWithValue(repository),
        tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
      ],
      child: const CasaEnJuegoApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CasaEnJuegoApp)),
  );
  container.read(appRouterProvider).go('/reviews');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final decision in ReviewDecision.values) {
    testWidgets('$decision removes the request and refreshes the badge', (
      tester,
    ) async {
      final repository = FakeReviewsRepository()..requests = [reviewRequest()];
      await startReviews(tester, repository);
      expect(find.text('1 POR REVISAR'), findsOneWidget);
      final button = find.text(
        decision == ReviewDecision.approved ? 'Aprobar' : 'Rechazar',
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repository.decision, decision);
      expect(repository.reviewerId, testUser.id);
      expect(find.text('No hay solicitudes por revisar'), findsOneWidget);
      expect(find.text('0 POR REVISAR'), findsOneWidget);
    });
  }

  testWidgets('Decisions are serialized while a request is in flight', (
    tester,
  ) async {
    final repository = FakeReviewsRepository()
      ..requests = [reviewRequest()]
      ..pendingResolution = Completer<void>();
    final container = await startReviews(tester, repository);
    await tester.ensureVisible(find.text('Aprobar'));
    await tester.tap(find.text('Aprobar'));
    await tester.pump();
    expect(find.text('Guardando decisión…'), findsOneWidget);
    final duplicate = await container
        .read(reviewActionProvider.notifier)
        .resolve('request-id', ReviewDecision.rejected);
    expect(duplicate, isFalse);
    expect(repository.resolveCalls, 1);
    repository.pendingResolution!.complete();
    await tester.pumpAndSettle();
    expect(repository.decision, ReviewDecision.approved);
  });

  testWidgets(
    'Own requests are hidden and cannot be resolved through the controller',
    (tester) async {
      final repository = FakeReviewsRepository()
        ..requests = [reviewRequest(userId: testUser.id)];
      final container = await startReviews(tester, repository);
      expect(find.text('Aprobar'), findsNothing);
      final result = await container
          .read(reviewActionProvider.notifier)
          .resolve('request-id', ReviewDecision.approved);
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(repository.resolveCalls, 0);
    },
  );

  testWidgets('Conflicting decisions are shown without reporting success', (
    tester,
  ) async {
    final repository = FakeReviewsRepository()
      ..requests = [reviewRequest()]
      ..resolveError = const ReviewFailure(
        'Otro miembro ya revisó esta solicitud.',
      );
    await startReviews(tester, repository);
    await tester.ensureVisible(find.text('Aprobar'));
    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();
    expect(find.text('Otro miembro ya revisó esta solicitud.'), findsOneWidget);
    expect(find.text('Solicitud aprobada.'), findsNothing);
    expect(repository.requests.length, 1);
  });

  testWidgets('Inbox errors can be retried', (tester) async {
    final repository = FakeReviewsRepository()
      ..loadError = const ReviewFailure('Error de prueba');
    await startReviews(tester, repository);
    expect(find.text('Error de prueba'), findsOneWidget);
    repository.loadError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('No hay solicitudes por revisar'), findsOneWidget);
  });

  testWidgets('Navigation enables reviews and returns to tasks', (
    tester,
  ) async {
    final container = await startReviews(tester, FakeReviewsRepository());
    await tester.tap(find.text('Tareas'));
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/tasks',
    );
    await tester.tap(find.text('Revisiones'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewsPage), findsOneWidget);
  });

  testWidgets('Small mobile screens can reach both decision buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await startReviews(
      tester,
      FakeReviewsRepository()..requests = [reviewRequest()],
    );
    await tester.scrollUntilVisible(
      find.text('Aprobar'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Aprobar').hitTestable(), findsOneWidget);
    expect(find.text('Rechazar').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
