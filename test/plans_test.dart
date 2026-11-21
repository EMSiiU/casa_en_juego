import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/core/theme/theme_mode_provider.dart';
import 'package:casa_en_juego/features/auth/models/app_user.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/plans/presentation/plans_page.dart';
import 'package:casa_en_juego/features/profile/providers/profile_providers.dart';
import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_profile_repository.dart';
import 'support/fake_reviews_repository.dart';
import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show FakeAuthRepository, testUser;

void main() {
  for (final hasCycle in [true, false]) {
    testWidgets('Plans navigation works with active membership = $hasCycle', (
      tester,
    ) async {
      final user = hasCycle
          ? testUser
          : const AppUser(
              id: 'member-id',
              name: 'Ana',
              email: 'ana@familia.es',
              role: UserRole.sibling,
              notificationsEnabled: true,
              isHouseholdMember: false,
            );
      final auth = FakeAuthRepository()..user = user;
      addTearDown(auth.events.close);
      final reviews = FakeReviewsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository()..user = user,
            ),
            reviewsRepositoryProvider.overrideWithValue(reviews),
            tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
          ],
          child: const CasaEnJuegoApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CasaEnJuegoApp)),
      );
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .length,
        hasCycle ? 5 : 2,
      );
      await tester.tap(find.widgetWithText(NavigationDestination, 'Planes'));
      await tester.pumpAndSettle();
      expect(find.byType(PlansPage), findsOneWidget);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/plans',
      );

      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [320.0, 1100.0]) {
        tester.view.physicalSize = Size(width, 720);
        await container
            .read(themeModeProvider.notifier)
            .setDarkMode(width == 320);
        await tester.pumpAndSettle();
        for (final name in ['Casa', 'Familia', 'Comunidad']) {
          final title = find.text(name);
          await tester.ensureVisible(title);
          await tester.pumpAndSettle();
          expect(title, findsOneWidget);
          final card = find.ancestor(of: title, matching: find.byType(Card));
          final button = tester.widget<FilledButton>(
            find.descendant(of: card, matching: find.byType(FilledButton)),
          );
          expect(button.onPressed, isNull);
        }
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/profile',
      );
    });
  }

  testWidgets('Plans direct links require an authenticated session', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const CasaEnJuegoApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CasaEnJuegoApp)),
    );
    container.read(appRouterProvider).go('/plans');
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/login',
    );
    expect(find.byType(PlansPage), findsNothing);
  });
}
