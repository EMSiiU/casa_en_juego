import 'dart:async';

import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/features/auth/models/app_user.dart';
import 'package:casa_en_juego/features/auth/models/auth_failure.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/profile/models/profile_failure.dart';
import 'package:casa_en_juego/features/profile/presentation/profile_page.dart';
import 'package:casa_en_juego/features/profile/providers/profile_providers.dart';
import 'package:casa_en_juego/features/activity/providers/activity_providers.dart';
import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_profile_repository.dart';
import 'support/fake_activity_repository.dart';
import 'support/fake_reviews_repository.dart';
import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show testUser, FakeAuthRepository;

Future<ProviderContainer> startProfile(
  WidgetTester tester,
  FakeProfileRepository repository, {
  FakeAuthRepository? auth,
}) async {
  final authRepository = auth ?? (FakeAuthRepository()..user = testUser);
  addTearDown(authRepository.events.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        profileRepositoryProvider.overrideWithValue(repository),
        tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
        reviewsRepositoryProvider.overrideWithValue(FakeReviewsRepository()),
        activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
      ],
      child: const CasaEnJuegoApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CasaEnJuegoApp)),
  );
  container.read(appRouterProvider).go('/profile');
  await tester.pumpAndSettle();
  return container;
}

Future<void> togglePreference(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(SwitchListTile));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(SwitchListTile));
}

void main() {
  testWidgets(
    'Profile shows user data and persists the preference without changing the auth route',
    (tester) async {
      final repository = FakeProfileRepository();
      final container = await startProfile(tester, repository);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('ana@familia.es'), findsOneWidget);
      expect(find.text('Miembro'), findsOneWidget);
      await togglePreference(tester);
      await tester.pumpAndSettle();
      expect(repository.savedUserId, testUser.id);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/profile',
      );
      container.invalidate(profileProvider);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    },
  );

  testWidgets(
    'A pending save blocks duplicate writes and does not prematurely flip the switch',
    (tester) async {
      final repository = FakeProfileRepository()
        ..pendingSave = Completer<void>();
      final container = await startProfile(tester, repository);
      await togglePreference(tester);
      await tester.pump();
      expect(find.text('Guardando preferencia…'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await container.read(profileProvider.notifier).setNotifications(false);
      expect(repository.saveCalls, 1);
      repository.pendingSave!.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    },
  );

  testWidgets('Failed saves retain the original value and allow retrying', (
    tester,
  ) async {
    final repository = FakeProfileRepository()
      ..saveError = const ProfileFailure('No se pudo guardar');
    await startProfile(tester, repository);
    await togglePreference(tester);
    await tester.pumpAndSettle();
    expect(find.text('No se pudo guardar'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    repository.saveError = null;
    await togglePreference(tester);
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets('Profile loading failures permit retrying', (tester) async {
    final repository = FakeProfileRepository()
      ..loadError = const ProfileFailure('Perfil no disponible');
    await startProfile(tester, repository);
    expect(find.text('Perfil no disponible'), findsOneWidget);
    repository.loadError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets(
    'Activity opened from profile keeps the profile tab selected and returns to profile',
    (tester) async {
      await startProfile(tester, FakeProfileRepository());
      await tester.ensureVisible(find.text('Mi actividad'));
      await tester.tap(find.text('Mi actividad'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar).last)
            .selectedIndex,
        3,
      );
      await tester.tap(find.byTooltip('Volver al perfil'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
    },
  );

  testWidgets('Closing the session returns to login; failures stay visible', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..user = testUser
      ..signOutError = const AuthFailure('No se pudo cerrar sesión');
    await startProfile(tester, FakeProfileRepository(), auth: auth);
    await tester.scrollUntilVisible(
      find.text('Cerrar sesión'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo cerrar sesión'), findsOneWidget);
    auth.signOutError = null;
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets(
    'Admin profiles display their real role and work on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeProfileRepository()
        ..user = const AppUser(
          id: 'member-id',
          name: 'Carlos',
          email: 'carlos@familia.es',
          role: UserRole.admin,
          notificationsEnabled: true,
        );
      await startProfile(tester, repository);
      expect(find.text('Administrador'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(SwitchListTile),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
