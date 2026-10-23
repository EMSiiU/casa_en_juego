import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/leaderboard/providers/leaderboard_providers.dart';
import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_leaderboard_repository.dart';
import 'support/fake_reviews_repository.dart';
import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show FakeAuthRepository, testUser;

void main() {
  for (final route in ['/tasks', '/leaderboard', '/reviews']) {
    testWidgets('Account menu signs out from $route', (tester) async {
      final auth = FakeAuthRepository()..user = testUser;
      addTearDown(auth.events.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
            reviewsRepositoryProvider.overrideWithValue(
              FakeReviewsRepository(),
            ),
            leaderboardRepositoryProvider.overrideWithValue(
              FakeLeaderboardRepository(),
            ),
          ],
          child: const CasaEnJuegoApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CasaEnJuegoApp)),
      );
      container.read(appRouterProvider).go(route);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Abrir cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(auth.user, isNull);
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });
  }
}
