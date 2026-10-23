import 'dart:async';

import 'package:casa_en_juego/core/constants/task_log_status.dart';
import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/features/admin/models/admin_dashboard.dart';
import 'package:casa_en_juego/features/admin/models/admin_failure.dart';
import 'package:casa_en_juego/features/admin/models/task_draft.dart';
import 'package:casa_en_juego/features/admin/presentation/task_catalog_page.dart';
import 'package:casa_en_juego/features/admin/providers/admin_providers.dart';
import 'package:casa_en_juego/features/auth/models/app_user.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/profile/providers/profile_providers.dart';
import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_admin_repository.dart';
import 'support/fake_profile_repository.dart';
import 'support/fake_reviews_repository.dart';
import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show testUser;

Future<ProviderContainer> startAdmin(
  WidgetTester tester,
  FakeAdminRepository repository, {
  AppUser user = adminUser,
  String location = '/admin',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        adminRepositoryProvider.overrideWithValue(repository),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository()..user = user,
        ),
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
  container.read(appRouterProvider).go(location);
  await tester.pumpAndSettle();
  return container;
}

Future<void> tapVisible(WidgetTester tester, String text) async {
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(
    tester.element(find.text(text).last),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Admin saves a new icon and daily frequency', (tester) async {
    final repository = FakeAdminRepository();
    await startAdmin(tester, repository, location: '/admin/tasks/task-id');
    await tester.ensureVisible(find.byTooltip('Cama'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cama'));
    await tapVisible(tester, 'Una vez al día');
    await tapVisible(tester, 'Guardar cambios');
    expect(repository.savedDraft!.iconName, 'bed');
    expect(repository.savedDraft!.isDailyLimited, isTrue);
    expect(repository.tasks.single.isDailyLimited, isTrue);
    expect(find.textContaining('Una vez al día'), findsOneWidget);
    await tapVisible(tester, 'Barrer el cuarto');
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      isTrue,
    );
  });

  test('Statistics only count approved snapshots and rank ties equally', () {
    final summary = SeasonSummary(
      season: adminSeason,
      logs: [
        ...adminLogs,
        const AdminLog(
          id: 'rejected',
          userId: 'leo',
          userName: 'Leo',
          status: TaskLogStatus.rejected,
          points: 100,
        ),
        const AdminLog(
          id: 'tied',
          userId: 'luis-id',
          userName: 'Luis',
          status: TaskLogStatus.approved,
          points: 8,
        ),
      ],
    );
    expect(summary.approvedPoints, 16);
    expect(summary.pendingCount, 1);
    expect(summary.participants, 3);
    expect(
      summary.results.take(2).every((result) => result.position == 1),
      isTrue,
    );
  });
  test('Task drafts reject invalid points and trim names', () {
    expect(
      () => TaskDraft(name: ' ', points: 3, iconName: 'broom', isActive: true),
      throwsA(isA<AdminFailure>()),
    );
    expect(
      () =>
          TaskDraft(name: 'Task', points: 0, iconName: 'broom', isActive: true),
      throwsA(isA<AdminFailure>()),
    );
    expect(
      () => TaskDraft(
        name: 'Task',
        points: 2147483648,
        iconName: 'broom',
        isActive: true,
      ),
      throwsA(isA<AdminFailure>()),
    );
    expect(
      TaskDraft(
        name: '  Barrer  ',
        points: 3,
        iconName: 'broom',
        isActive: true,
      ).name,
      'Barrer',
    );
  });
  testWidgets('Members cannot enter admin routes or invoke admin mutations', (
    tester,
  ) async {
    final repository = FakeAdminRepository();
    final container = await startAdmin(
      tester,
      repository,
      user: testUser,
      location: '/admin/tasks/new',
    );
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/profile',
    );
    final subscription = container.listen(adminActionProvider, (_, _) {});
    final saved = await container
        .read(adminActionProvider.notifier)
        .saveTask(
          draft: TaskDraft(
            name: 'Task',
            points: 3,
            iconName: 'broom',
            isActive: true,
          ),
        );
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(repository.saveCalls, 0);
    subscription.close();
  });
  testWidgets('Admins access the panel through profile', (tester) async {
    await startAdmin(tester, FakeAdminRepository(), location: '/profile');
    await tapVisible(tester, 'Cuidar del equipo');
    expect(find.text('TEMPORADA ACTUAL · ACTIVA'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });
  testWidgets(
    'New tasks validate fields and appear in the catalog after saving',
    (tester) async {
      final repository = FakeAdminRepository();
      await startAdmin(tester, repository, location: '/admin/tasks');
      await tapVisible(tester, 'Nueva tarea');
      await tapVisible(tester, 'Guardar cambios');
      expect(repository.saveCalls, 0);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Lavar ventanas',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '6');
      await tapVisible(tester, 'Guardar cambios');
      expect(repository.savedDraft!.points, 6);
      expect(find.byType(TaskCatalogPage), findsOneWidget);
      expect(find.text('Lavar ventanas'), findsOneWidget);
    },
  );
  testWidgets('Editing points and deactivating preserves recorded scores', (
    tester,
  ) async {
    final repository = FakeAdminRepository();
    await startAdmin(tester, repository, location: '/admin/tasks');
    await tapVisible(tester, 'Barrer el cuarto');
    await tester.enterText(find.byType(TextFormField).at(1), '12');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SwitchListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile).last);
    await tapVisible(tester, 'Guardar cambios');
    expect(repository.tasks.single.points, 12);
    expect(repository.tasks.single.isActive, isFalse);
    expect(repository.dashboard.active!.approvedPoints, 8);
    expect(find.text('12 puntos · Inactiva · Repetible'), findsOneWidget);
  });
  testWidgets(
    'Closing requires confirmation and preserves results before a new season starts at zero',
    (tester) async {
      final repository = FakeAdminRepository();
      await startAdmin(tester, repository);
      await tapVisible(tester, 'Finalizar ciclo');
      expect(find.text('¿Finalizar Octubre 2026?'), findsOneWidget);
      expect(find.textContaining('Hay 1 solicitud pendiente'), findsOneWidget);
      expect(repository.closeCalls, 0);
      await tapVisible(tester, 'Cancelar');
      expect(repository.closeCalls, 0);
      await tapVisible(tester, 'Finalizar ciclo');
      await tapVisible(tester, 'Finalizar ciclo');
      expect(repository.closeCalls, 1);
      expect(repository.dashboard.latestClosed!.approvedPoints, 8);
      expect(find.text('Un nuevo comienzo'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Noviembre 2026');
      await tapVisible(tester, 'Iniciar nuevo ciclo');
      expect(repository.startCalls, 1);
      expect(repository.dashboard.active!.approvedPoints, 0);
      expect(repository.dashboard.latestClosed!.approvedPoints, 8);
      expect(find.text('Noviembre 2026'), findsOneWidget);
    },
  );
  testWidgets(
    'A cycle cannot start while one is active; duplicate actions are blocked',
    (tester) async {
      final repository = FakeAdminRepository();
      final container = await startAdmin(tester, repository);
      final premature = await container
          .read(adminActionProvider.notifier)
          .startSeason('Next');
      await tester.pumpAndSettle();
      expect(premature, isFalse);
      expect(repository.startCalls, 0);
      repository.pendingMutation = Completer<void>();
      await tapVisible(tester, 'Finalizar ciclo');
      final pending = container
          .read(adminActionProvider.notifier)
          .closeSeason('season-id');
      await tester.pump();
      expect(
        await container
            .read(adminActionProvider.notifier)
            .closeSeason('season-id'),
        isFalse,
      );
      expect(repository.closeCalls, 1);
      repository.pendingMutation!.complete();
      expect(await pending, isTrue);
      await tester.pumpAndSettle();
    },
  );
  testWidgets('Load failures permit retrying', (tester) async {
    final repository = FakeAdminRepository()
      ..loadError = const AdminFailure('Error de prueba');
    await startAdmin(tester, repository);
    expect(find.text('Error de prueba'), findsOneWidget);
    repository.loadError = null;
    await tapVisible(tester, 'Reintentar');
    expect(find.text('TEMPORADA ACTUAL · ACTIVA'), findsOneWidget);
  });
  testWidgets('Task editing fits a small mobile screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await startAdmin(
      tester,
      FakeAdminRepository(),
      location: '/admin/tasks/task-id',
    );
    await tapVisible(tester, 'Guardar cambios');
    expect(tester.takeException(), isNull);
  });
}
