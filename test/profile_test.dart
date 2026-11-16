import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/core/theme/theme_mode_provider.dart';
import 'package:casa_en_juego/features/admin/models/admin_dashboard.dart';
import 'package:casa_en_juego/features/admin/models/admin_season.dart';
import 'package:casa_en_juego/features/admin/providers/admin_providers.dart';
import 'package:casa_en_juego/features/auth/models/app_user.dart';
import 'package:casa_en_juego/features/auth/models/auth_failure.dart';
import 'package:casa_en_juego/features/auth/presentation/widgets/account_avatar.dart';
import 'package:casa_en_juego/features/auth/providers/account_photo_providers.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/auth/repositories/account_photo_repository.dart';
import 'package:casa_en_juego/features/profile/models/profile_failure.dart';
import 'package:casa_en_juego/features/profile/models/profile_photo.dart';
import 'package:casa_en_juego/features/profile/presentation/profile_page.dart';
import 'package:casa_en_juego/features/profile/providers/profile_providers.dart';
import 'package:casa_en_juego/features/activity/providers/activity_providers.dart';
import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_profile_repository.dart';
import 'support/fake_activity_repository.dart';
import 'support/fake_admin_repository.dart';
import 'support/fake_reviews_repository.dart';
import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show testUser, FakeAuthRepository;

Future<ProviderContainer> startProfile(
  WidgetTester tester,
  FakeProfileRepository repository, {
  FakeAuthRepository? auth,
  SharedPreferencesWithCache? appearance,
  AccountPhotoRepository? photos,
  Future<ProfilePhoto?> Function()? pickPhoto,
  FakeAdminRepository? admin,
}) async {
  final authRepository = auth ?? (FakeAuthRepository()..user = testUser);
  addTearDown(authRepository.events.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        themePreferencesProvider.overrideWithValue(appearance),
        profileRepositoryProvider.overrideWithValue(repository),
        accountPhotoRepositoryProvider.overrideWithValue(photos ?? _Photos()),
        if (pickPhoto != null)
          profilePhotoPickerProvider.overrideWithValue(pickPhoto),
        tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
        reviewsRepositoryProvider.overrideWithValue(FakeReviewsRepository()),
        activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
        if (admin != null) adminRepositoryProvider.overrideWithValue(admin),
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

class _Photos implements AccountPhotoRepository {
  final saved = <String, Uint8List>{};
  String? contentType;

  @override
  Future<Uint8List?> load(String userId) async => saved[userId];

  @override
  Future<void> save(String userId, Uint8List bytes, String contentType) async {
    saved[userId] = bytes;
    this.contentType = contentType;
  }

  @override
  Future<void> remove(String userId) async => saved.remove(userId);
}

final notificationSwitch = find.widgetWithText(
  SwitchListTile,
  'Avisos de revisión',
);

class _MemoryAppearance implements SharedPreferencesWithCache {
  final _values = <String, String>{};

  String? get savedMode => _values[themePreferenceKey];

  @override
  Object? get(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> togglePreference(WidgetTester tester) async {
  await tester.ensureVisible(notificationSwitch);
  await tester.pumpAndSettle();
  await tester.tap(notificationSwitch);
}

void main() {
  testWidgets('Joining by code opens Tasks with member permissions', (
    tester,
  ) async {
    const personal = AppUser(
      id: 'member-id',
      name: 'Ana',
      email: 'ana@familia.es',
      role: UserRole.sibling,
      notificationsEnabled: false,
      isHouseholdMember: false,
    );
    final auth = FakeAuthRepository()..user = personal;
    final repository = FakeProfileRepository()..user = personal;
    String? received;
    repository.onJoinCycle = (code) async {
      received = code;
      auth.user = repository.user = testUser;
    };
    final container = await startProfile(tester, repository, auth: auth);
    await tester.ensureVisible(find.text('Unirme con código'));
    await tester.tap(find.text('Unirme con código'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '1234-abcd-5678');
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();
    expect(received, '1234-abcd-5678');
    expect(find.text('¡Hola, Ana!'), findsOneWidget);
    final user = container.read(currentUserProvider).asData?.value;
    expect(user?.isHouseholdMember, isTrue);
    expect(user?.isAdmin, isFalse);
  });

  testWidgets(
    'An account without a cycle can create one and open its admin panel',
    (tester) async {
      const personal = AppUser(
        id: 'personal-id',
        name: 'Ana',
        email: 'ana@example.com',
        role: UserRole.sibling,
        notificationsEnabled: false,
        isHouseholdMember: false,
      );
      final auth = FakeAuthRepository()..user = personal;
      final admin = FakeAdminRepository();
      ({String name, DateTime plannedEndDate})? saved;
      final repository = FakeProfileRepository()..user = personal;
      repository.onCreateCycle = (name, date) async {
        saved = (name: name, plannedEndDate: date);
        repository.user = const AppUser(
          id: 'personal-id',
          name: 'Ana',
          email: 'ana@example.com',
          role: UserRole.admin,
          notificationsEnabled: false,
        );
        auth.user = repository.user;
        admin.dashboard = AdminDashboard(
          active: SeasonSummary(
            season: AdminSeason(
              id: 'new-season',
              name: name,
              startDate: DateTime.now(),
              status: AdminSeasonStatus.active,
              plannedDurationDays: 1,
              plannedEndDate: date,
            ),
            logs: const [],
          ),
        );
      };
      final container = await startProfile(
        tester,
        repository,
        auth: auth,
        admin: admin,
      );
      final router = container.read(appRouterProvider);

      router.go('/admin/tasks');
      await tester.pumpAndSettle();
      expect(find.text('Aún no tienes un ciclo'), findsOneWidget);
      expect(find.text('Editar nombre'), findsOneWidget);
      await tester.ensureVisible(find.text('Administración'));
      await tester.tap(find.text('Administración'));
      await tester.pumpAndSettle();
      expect(find.text('Tu primer ciclo'), findsOneWidget);
      expect(find.text('Gestionar tareas'), findsNothing);
      await tester.tap(find.text('Crear ciclo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '  Mi ciclo  ');
      await tester.tap(find.text('Iniciar ciclo'));
      await tester.pumpAndSettle();
      expect(find.text('Elige una fecha de fin prevista.'), findsOneWidget);
      expect(saved, isNull);

      await tester.tap(find.text('Elegir fecha'));
      await tester.pumpAndSettle();
      final calendar = find.byType(DatePickerDialog);
      final tomorrow = tester.widget<DatePickerDialog>(calendar).firstDate;
      final strings = MaterialLocalizations.of(tester.element(calendar));
      await tester.tap(find.text(strings.okButtonLabel));
      await tester.pumpAndSettle();
      expect(find.text('Duración prevista · 1 día'), findsOneWidget);
      await tester.tap(find.text('Iniciar ciclo'));
      await tester.pumpAndSettle();
      expect(saved, (name: 'Mi ciclo', plannedEndDate: tomorrow));
      expect(
        container.read(currentUserProvider).asData?.value?.isAdmin,
        isTrue,
      );

      expect(find.text('Mi ciclo'), findsOneWidget);
      expect(
        find.text('Fin previsto · ${strings.formatShortDate(tomorrow)}'),
        findsOneWidget,
      );
      expect(find.text('Duración prevista · 1 día'), findsOneWidget);
    },
  );

  testWidgets('A custom photo can be added, replaced and removed', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aT6sAAAAASUVORK5CYII=',
    );
    final photos = _Photos();
    ProfilePhoto? selected;
    final container = await startProfile(
      tester,
      FakeProfileRepository(),
      photos: photos,
      pickPhoto: () async => selected,
    );
    final router = container.read(appRouterProvider);
    final id = testUser.id;
    Future<void> tap(String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tap('Agregar foto');
    expect(photos.saved, isEmpty);
    expect(find.text('A'), findsOneWidget);

    selected = ProfilePhoto(bytes, 'image/png');
    await tap('Agregar foto');
    expect(photos.saved[id], same(bytes));
    expect(photos.contentType, 'image/png');
    expect(find.text('Quitar foto'), findsOneWidget);

    final replacement = Uint8List.fromList(bytes);
    selected = ProfilePhoto(replacement, 'image/png');
    await tap('Cambiar foto');
    expect(photos.saved[id], same(replacement));
    router.go('/tasks');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AccountAvatar),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );

    router.go('/profile');
    await tester.pumpAndSettle();
    await tap('Quitar foto');
    expect(photos.saved, isEmpty);
    expect(find.text('Agregar foto'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('A saved name updates Profile and the Tasks greeting', (
    tester,
  ) async {
    final repository = FakeProfileRepository();
    final container = await startProfile(tester, repository);
    await tester.tap(find.text('Editar nombre'));
    await tester.pumpAndSettle();
    final field = find.byType(TextFormField);
    await tester.enterText(field, '  ');
    await tester.tap(find.text('Guardar nombre'));
    await tester.pumpAndSettle();
    expect(
      find.text('Escribe un nombre de 1 a 100 caracteres.'),
      findsOneWidget,
    );
    expect(repository.savedName, isNull);
    await tester.enterText(field, '  Ana Marín  ');
    repository.pendingSave = Completer<void>();
    await tester.tap(find.text('Guardar nombre'));
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go('/tasks');
    await tester.pumpAndSettle();
    expect(find.text('¡Hola, Ana!'), findsOneWidget);
    repository.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(repository.savedName, 'Ana Marín');
    expect(find.text('¡Hola, Ana Marín!'), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);

    container.read(appRouterProvider).go('/profile');
    await tester.pumpAndSettle();
    expect(find.text('Ana Marín'), findsOneWidget);
  });

  testWidgets(
    'Profile and Tasks share the provider photo and fallback initials',
    (tester) async {
      const url = 'https://avatars.githubusercontent.com/u/1';
      final auth = FakeAuthRepository()
        ..user = const AppUser(
          id: 'member-id',
          name: 'Ana',
          email: 'ana@familia.es',
          role: UserRole.sibling,
          notificationsEnabled: true,
          avatarUrl: url,
        );
      final container = await startProfile(
        tester,
        FakeProfileRepository(),
        auth: auth,
      );

      void expectAvatar() {
        expect(
          tester.widget<AccountAvatar>(find.byType(AccountAvatar)).avatarUrl,
          url,
        );
        expect(find.text('A'), findsOneWidget);
      }

      // Widget tests do not fetch real network images. The fallback stays visible.
      expectAvatar();
      container.read(appRouterProvider).go('/tasks');
      await tester.pumpAndSettle();
      expectAvatar();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Profile switches the whole app and restores the saved theme', (
    tester,
  ) async {
    final appearance = _MemoryAppearance();
    final container = await startProfile(
      tester,
      FakeProfileRepository(),
      appearance: appearance,
    );
    final themeSwitch = find.widgetWithText(SwitchListTile, 'Modo oscuro');
    await tester.scrollUntilVisible(
      themeSwitch,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<SwitchListTile>(themeSwitch).value, isTrue);
    await tester.tap(themeSwitch);
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(ProfilePage)));
    expect(theme.brightness, Brightness.light);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'DM Sans');
    expect(appearance.savedMode, 'light');

    container.read(appRouterProvider).go('/tasks');
    await tester.pumpAndSettle();
    final tasksContext = tester.element(find.byType(Scaffold).last);
    expect(Theme.of(tasksContext).brightness, Brightness.light);

    final reopened = ProviderContainer(
      overrides: [themePreferencesProvider.overrideWithValue(appearance)],
    );
    addTearDown(reopened.dispose);
    expect(reopened.read(themeModeProvider), ThemeMode.light);
    await reopened.read(themeModeProvider.notifier).setDarkMode(true);
    expect(appearance.savedMode, 'dark');
  });

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
      expect(tester.widget<SwitchListTile>(notificationSwitch).value, isFalse);
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
      expect(tester.widget<SwitchListTile>(notificationSwitch).value, isFalse);
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
      expect(find.text('Guardando cambios…'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(notificationSwitch).value, isTrue);
      await container.read(profileProvider.notifier).setNotifications(false);
      expect(repository.saveCalls, 1);
      repository.pendingSave!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(notificationSwitch).value, isFalse);
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
    expect(tester.widget<SwitchListTile>(notificationSwitch).value, isTrue);
    repository.saveError = null;
    await togglePreference(tester);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(notificationSwitch).value, isFalse);
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
        notificationSwitch,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(notificationSwitch.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
