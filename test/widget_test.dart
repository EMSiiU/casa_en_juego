import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';

import 'support/fake_reviews_repository.dart';
import 'support/fake_profile_repository.dart';

import 'dart:async';

import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';

import 'support/fake_tasks_repository.dart';

import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/features/auth/models/app_user.dart';
import 'package:casa_en_juego/features/auth/models/auth_failure.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/auth/repositories/auth_repository.dart';
import 'package:casa_en_juego/features/profile/providers/profile_providers.dart';
import 'package:casa_en_juego/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const testUser = AppUser(
  id: 'member-id',
  name: 'Ana',
  email: 'ana@familia.es',
  role: UserRole.sibling,
  notificationsEnabled: true,
);

class FakeAuthRepository implements AuthRepository {
  final events = StreamController<AppUser?>.broadcast();
  AppUser? user;
  Object? signInError;
  Object? signOutError;
  String? submittedEmail;
  String? submittedPassword;
  int signInCalls = 0;
  Completer<void>? pendingSignIn;
  String? signUpName;
  String? resentEmail;
  String? resetEmail;
  String? newPassword;
  String? confirmedCode;

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    signUpName = name;
    submittedEmail = email;
    submittedPassword = password;
  }

  @override
  Future<void> resendSignUpCode(String email) async => resentEmail = email;

  @override
  Future<void> confirmEmail({
    required String email,
    required String code,
  }) async {
    confirmedCode = code;
    user = AppUser(
      id: 'personal-account',
      name: signUpName ?? 'Elena',
      email: email,
      role: UserRole.sibling,
      notificationsEnabled: false,
      isHouseholdMember: false,
    );
    events.add(user);
  }

  @override
  Future<void> requestPasswordReset(String email) async => resetEmail = email;

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    resetEmail = email;
    confirmedCode = code;
    newPassword = password;
  }

  @override
  Stream<AppUser?> watchUser() async* {
    yield user;
    yield* events.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    submittedEmail = email;
    submittedPassword = password;
    if (pendingSignIn != null) await pendingSignIn!.future;
    if (signInError != null) throw signInError!;
    user = testUser;
    events.add(user);
  }

  @override
  Future<void> signOut() async {
    if (signOutError != null) throw signOutError!;
    user = null;
    events.add(null);
  }
}

Future<ProviderContainer> startApp(
  WidgetTester tester,
  FakeAuthRepository repository, {
  FakeProfileRepository? profile,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reviewsRepositoryProvider.overrideWithValue(FakeReviewsRepository()),
        authRepositoryProvider.overrideWithValue(repository),
        if (profile != null)
          profileRepositoryProvider.overrideWithValue(profile),
        tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
      ],
      child: const CasaEnJuegoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CasaEnJuegoApp)));
}

Finder input(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> enterCredentials(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'ana@familia.es');
  await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
  await tester.ensureVisible(find.text('Iniciar sesión'));
  await tester.tap(find.text('Iniciar sesión'));
}

void main() {
  testWidgets('Signup stays anonymous until the email code is confirmed', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final profile = FakeProfileRepository()
      ..user = const AppUser(
        id: 'personal-account',
        name: 'Elena',
        email: 'elena@example.com',
        role: UserRole.sibling,
        notificationsEnabled: false,
        isHouseholdMember: false,
      );
    addTearDown(auth.events.close);
    final container = await startApp(tester, auth, profile: profile);
    await tapText(tester, 'Crear cuenta');
    await tester.enterText(input('Nombre'), 'Elena');
    await tester.enterText(input('Correo electrónico'), 'elena@example.com');
    await tester.enterText(input('Contraseña'), 'sample-password');
    await tester.enterText(input('Repite la contraseña'), 'sample-password');
    await tapText(tester, 'Enviar código de confirmación');
    expect(auth.signUpName, 'Elena');
    expect(container.read(currentUserProvider).asData?.value, isNull);

    await tapText(tester, 'Reenviar código');
    expect(auth.resentEmail, 'elena@example.com');
    await tester.enterText(input('Código del correo'), '123456');
    await tapText(tester, 'Confirmar correo');
    expect(auth.confirmedCode, '123456');
    expect(find.text('Aún no tienes un ciclo'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    container.read(appRouterProvider).go('/reviews');
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes un ciclo'), findsOneWidget);
  });

  testWidgets('Recovery validates the new password and returns to login', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.events.close);
    await startApp(tester, auth);
    await tapText(tester, 'Olvidé mi contraseña');
    await tester.enterText(input('Correo electrónico'), 'elena@example.com');
    await tapText(tester, 'Enviar código de recuperación');
    expect(auth.resetEmail, 'elena@example.com');
    await tester.enterText(input('Código del correo'), '123456');
    await tester.enterText(input('Nueva contraseña'), 'new-password');
    await tester.enterText(input('Repite la contraseña'), 'different-password');
    await tapText(tester, 'Guardar nueva contraseña');
    expect(auth.newPassword, isNull);
    expect(find.text('Las contraseñas deben coincidir.'), findsOneWidget);
    await tester.enterText(input('Repite la contraseña'), 'new-password');
    await tapText(tester, 'Guardar nueva contraseña');
    expect(auth.newPassword, 'new-password');
    expect(auth.user, isNull);
    await tapText(tester, 'Ir a iniciar sesión');
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('Login remains usable on a small mobile screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeAuthRepository();
    addTearDown(repository.events.close);
    await startApp(tester, repository);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('User model reads the database role', () {
    final user = AppUser.fromJson({
      'id': 'admin-id',
      'name': 'Carlos',
      'email': 'carlos@familia.es',
      'role': 'admin',
      'notifications_enabled': false,
    });
    expect(user.isAdmin, isTrue);
    expect(user.notificationsEnabled, isFalse);
    expect(
      () => AppUser.fromJson({
        'id': 'id',
        'name': 'name',
        'email': 'email',
        'role': 'unknown',
        'notifications_enabled': true,
      }),
      throwsArgumentError,
    );
  });

  testWidgets(
    'Signed out users are redirected and the login form validates input',
    (tester) async {
      final repository = FakeAuthRepository();
      addTearDown(repository.events.close);
      final container = await startApp(tester, repository);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/login',
      );
      final context = tester.element(find.byType(Scaffold));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(Theme.of(context).colorScheme.primary, const Color(0xFFCBBDF8));
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe tu correo electrónico.'), findsOneWidget);
      expect(find.text('Escribe tu contraseña.'), findsOneWidget);
      expect(repository.signInCalls, 0);
      container.read(appRouterProvider).go('/tasks');
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/login',
      );
    },
  );

  testWidgets('Password visibility can be toggled', (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.events.close);
    await startApp(tester, repository);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isTrue,
    );
    await tester.ensureVisible(find.byTooltip('Mostrar contraseña'));
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isFalse,
    );
  });

  testWidgets(
    'Login prevents duplicate submissions and opens the protected route',
    (tester) async {
      final repository = FakeAuthRepository()
        ..pendingSignIn = Completer<void>();
      addTearDown(repository.events.close);
      final container = await startApp(tester, repository);
      await enterCredentials(tester);
      await tester.pump();
      expect(find.text('Iniciando sesión…'), findsOneWidget);
      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'other', password: 'other');
      expect(repository.signInCalls, 1);
      repository.pendingSignIn!.complete();
      await tester.pumpAndSettle();
      expect(repository.submittedEmail, 'ana@familia.es');
      expect(repository.submittedPassword, 'test-password');
      expect(find.text('¡Hola, Ana!'), findsOneWidget);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/tasks',
      );
      await tester.tap(find.byTooltip('Abrir cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión'), findsOneWidget);
    },
  );

  testWidgets('Login failures remain on the form and allow retrying', (
    tester,
  ) async {
    final repository = FakeAuthRepository()
      ..signInError = const AuthFailure('Credenciales incorrectas.');
    addTearDown(repository.events.close);
    await startApp(tester, repository);
    await enterCredentials(tester);
    await tester.pumpAndSettle();
    expect(find.text('Credenciales incorrectas.'), findsOneWidget);
    repository.signInError = null;
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola, Ana!'), findsOneWidget);
  });

  testWidgets(
    'Restored sessions open the protected route and sign out failures are visible',
    (tester) async {
      final repository = FakeAuthRepository()..user = testUser;
      addTearDown(repository.events.close);
      final container = await startApp(tester, repository);
      expect(find.text('¡Hola, Ana!'), findsOneWidget);
      repository.signOutError = const AuthFailure('No se pudo cerrar sesión.');
      await tester.tap(find.byTooltip('Abrir cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo cerrar sesión.'), findsOneWidget);
      container.read(appRouterProvider).go('/login');
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/tasks',
      );
    },
  );

  testWidgets('Profile failures block protected routes and can be retried', (
    tester,
  ) async {
    final repository = FakeAuthRepository()..user = testUser;
    addTearDown(repository.events.close);
    final container = await startApp(tester, repository);
    repository.events.addError(const AuthFailure('Perfil no disponible.'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil no disponible.'), findsOneWidget);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/session',
    );
    expect(find.text('¡Hola, Ana!'), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola, Ana!'), findsOneWidget);
  });
}
