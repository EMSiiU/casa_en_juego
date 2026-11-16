import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/core/theme/app_page_bar.dart';
import 'package:casa_en_juego/core/theme/app_theme.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/leaderboard/providers/leaderboard_providers.dart';
import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_leaderboard_repository.dart';
import 'support/fake_reviews_repository.dart';
import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show FakeAuthRepository, testUser;

void main() {
  testWidgets(
    'Page bar aligns its title and account action with page content',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      for (final width in [320.0, 1100.0]) {
        tester.view.physicalSize = Size(width, 720);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery.withClampedTextScaling(
              minScaleFactor: 2,
              maxScaleFactor: 2,
              child: child!,
            ),
            home: const Scaffold(
              appBar: AppPageBar(
                title: '¡Hola, persona con un nombre largo!',
                subtitle: 'CASA EN JUEGO',
                trailing: Icon(Icons.person, size: 40),
              ),
            ),
          ),
        );
        final title = find.text('¡Hola, persona con un nombre largo!');
        final contentWidth = width > 600 ? 600 : width;
        final margin = (width - contentWidth) / 2 + 20;
        expect(tester.getSize(find.byType(AppBar)).height, 80);
        expect(tester.getTopLeft(title).dx, margin);
        expect(
          tester.getTopRight(find.byIcon(Icons.person)).dx,
          width - margin,
        );
        expect(tester.widget<Text>(title).style?.fontFamily, 'DM Sans');
        expect(tester.takeException(), isNull);
      }
    },
  );

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
