import 'dart:async';

import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/core/theme/app_theme.dart';
import 'package:casa_en_juego/features/auth/models/app_user.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/onboarding/presentation/onboarding_dialog.dart';
import 'package:casa_en_juego/features/onboarding/providers/onboarding_session_provider.dart';
import 'package:casa_en_juego/features/profile/providers/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_test.dart' show startProfile;
import 'support/fake_profile_repository.dart';
import 'widget_test.dart' show FakeAuthRepository, testUser;

const freeUser = AppUser(
  id: 'member-id',
  name: 'Ana',
  email: 'ana@example.com',
  role: UserRole.sibling,
  notificationsEnabled: false,
  isHouseholdMember: false,
);

Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Session resets after logout but not profile refresh or cycle closure',
    () async {
      final events = StreamController<AppUser?>.broadcast();
      final container = ProviderContainer(
        overrides: [currentUserProvider.overrideWith((ref) => events.stream)],
      );
      final subscription = container.listen(
        onboardingSessionProvider,
        (_, _) {},
      );
      addTearDown(() {
        subscription.close();
        container.dispose();
        events.close();
      });
      events.add(freeUser);
      await container.pump();
      expect(container.read(onboardingSessionProvider), freeUser.id);
      container.read(onboardingSessionProvider.notifier).markShown(freeUser.id);
      events.add(freeUser);
      await container.pump();
      expect(container.read(onboardingSessionProvider), isNull);
      events.add(null);
      await container.pump();
      events.add(freeUser);
      await container.pump();
      expect(container.read(onboardingSessionProvider), freeUser.id);
      events.add(testUser);
      await container.pump();
      events.add(freeUser);
      await container.pump();
      expect(container.read(onboardingSessionProvider), isNull);
    },
  );

  testWidgets(
    'Free account sees six steps, previous works and final only closes',
    (tester) async {
      final auth = FakeAuthRepository()..user = freeUser;
      await startProfile(
        tester,
        FakeProfileRepository()..user = freeUser,
        auth: auth,
        dismissTutorial: false,
      );
      expect(find.text('Paso 1 de 6'), findsOneWidget);
      await tap(tester, 'Siguiente');
      expect(find.text('Crea un ciclo o únete'), findsOneWidget);
      await tap(tester, 'Atrás');
      expect(find.text('Paso 1 de 6'), findsOneWidget);
      for (var step = 1; step < 6; step++) {
        await tap(tester, 'Siguiente');
      }
      expect(find.text('Finaliza un ciclo'), findsOneWidget);
      expect(find.text('Omitir'), findsNothing);
      expect(find.text('Atrás'), findsNothing);
      await tap(tester, 'Cerrar');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Tu perfil'), findsOneWidget);
    },
  );

  testWidgets(
    'Skip does not repeat on refresh/navigation; same account login repeats',
    (tester) async {
      final auth = FakeAuthRepository()..user = freeUser;
      final container = await startProfile(
        tester,
        FakeProfileRepository()..user = freeUser,
        auth: auth,
        dismissTutorial: false,
      );
      await tap(tester, 'Omitir');
      container.invalidate(currentUserProvider);
      container.invalidate(profileProvider);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    container.read(appRouterProvider).go('/profile/lugares');
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/profile');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      auth.user = null;
      auth.events.add(null);
      await tester.pumpAndSettle();
      auth.user = freeUser;
      auth.events.add(freeUser);
      await tester.pumpAndSettle();
      expect(find.text('Paso 1 de 6'), findsOneWidget);
    },
  );

  testWidgets('Member sees tutorial manually, always starting from step one', (
    tester,
  ) async {
    await startProfile(tester, FakeProfileRepository());
    expect(find.byType(AlertDialog), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Ver tutorial'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Ver tutorial');
    await tap(tester, 'Siguiente');
    await tap(tester, 'Omitir');
    await tap(tester, 'Ver tutorial');
    expect(find.text('Paso 1 de 6'), findsOneWidget);
  });

  testWidgets('Changing account closes a tutorial from the previous account', (
    tester,
  ) async {
    final auth = FakeAuthRepository()..user = freeUser;
    await startProfile(
      tester,
      FakeProfileRepository()..user = freeUser,
      auth: auth,
      dismissTutorial: false,
    );
    expect(find.text('Paso 1 de 6'), findsOneWidget);
    auth.user = null;
    auth.events.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('All steps fit small screen, large text and dark=$dark', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Stream.value(freeUser)),
          ],
          child: MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      showOnboardingDialog(context, accountId: freeUser.id),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Abrir');
      for (var step = 1; step <= 6; step++) {
        expect(find.text('Paso $step de 6'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tap(tester, step == 6 ? 'Cerrar' : 'Siguiente');
      }
    });
  }
}
