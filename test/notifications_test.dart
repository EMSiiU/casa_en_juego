import 'dart:async';

import 'package:casa_en_juego/core/router/app_router.dart';
import 'package:casa_en_juego/features/activity/providers/activity_providers.dart';
import 'package:casa_en_juego/features/auth/models/app_user.dart';
import 'package:casa_en_juego/features/auth/providers/auth_providers.dart';
import 'package:casa_en_juego/features/notifications/models/push_notice.dart';
import 'package:casa_en_juego/features/notifications/providers/notification_providers.dart';
import 'package:casa_en_juego/features/notifications/services/notification_session.dart';
import 'package:casa_en_juego/features/reviews/providers/reviews_providers.dart';
import 'package:casa_en_juego/features/tasks/providers/tasks_providers.dart';
import 'package:casa_en_juego/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_activity_repository.dart';
import 'support/fake_notification_services.dart';
import 'support/fake_reviews_repository.dart';
import 'support/fake_tasks_repository.dart';
import 'widget_test.dart' show testUser, FakeAuthRepository;

const notice = PushNotice(
  id: 'notice-id',
  recipientId: 'member-id',
  kind: PushNoticeKind.submitted,
);
const disabledUser = AppUser(
  id: 'member-id',
  name: 'Ana',
  email: 'ana@familia.es',
  role: UserRole.sibling,
  notificationsEnabled: false,
);

void main() {
  late FakePushGateway gateway;
  late FakeNotificationRepository repository;
  late NotificationSession session;
  setUp(() {
    gateway = FakePushGateway();
    repository = FakeNotificationRepository();
    session = NotificationSession(gateway: gateway, repository: repository);
  });
  tearDown(() async {
    session.dispose();
    await gateway.close();
  });

  test('Malformed or unknown payloads cannot supply navigation routes', () {
    expect(
      PushNotice.fromData({
        'kind': 'admin',
        'notification_id': 'x',
        'recipient_id': 'a',
      }),
      isNull,
    );
    expect(
      PushNotice.fromData({
        'kind': 'submitted',
        'notification_id': 1,
        'recipient_id': 'a',
      }),
      isNull,
    );
    expect(
      PushNotice.fromData({
        'kind': 'approved',
        'notification_id': 'x',
        'recipient_id': 'a',
      })!.route,
      '/tasks/activity',
    );
  });
  test('Reminders are recognized and open the tasks page', () {
    final reminder = PushNotice.fromData({
      'kind': 'reminder',
      'notification_id': 'reminder-id',
      'recipient_id': 'member-id',
    });
    expect(reminder!.route, '/tasks');
    expect(reminder.message, contains('Hoy todavía'));
  });
  test(
    'Disabled preference never requests permission or registers a device',
    () async {
      await session.syncUser(disabledUser);
      expect(gateway.permissionRequests, 0);
      expect(repository.registered, isEmpty);
      expect(session.status, PushDeviceStatus.disabled);
    },
  );
  test('Denied system permission is distinct from saved preference', () async {
    gateway.allowed = false;
    await session.syncUser(testUser);
    expect(repository.registered, isEmpty);
    expect(session.status, PushDeviceStatus.denied);
  });
  test(
    'Token rotation registers the replacement and removes the previous binding',
    () async {
      await session.syncUser(testUser);
      await session.syncUser(
        testUser,
        requestPermission: false,
        token: 'replacement-token',
      );
      expect(repository.registered, ['device-token-001', 'replacement-token']);
      expect(repository.unregistered, ['device-token-001']);
      expect(session.status, PushDeviceStatus.ready);
    },
  );
  test(
    'Logout waits for an in-flight registration and then removes it',
    () async {
      repository.pendingRegister = Completer<void>();
      final registering = session.syncUser(testUser);
      await Future<void>.delayed(Duration.zero);
      final disconnecting = session.disconnect();
      repository.pendingRegister!.complete();
      await registering;
      await disconnecting;
      expect(repository.unregistered, ['device-token-001']);
      expect(gateway.deletes, 1);
      expect(session.user, isNull);
    },
  );
  test(
    'Provider revocation still allows logout when backend cleanup fails',
    () async {
      await session.syncUser(testUser);
      repository.unregisterError = Exception('offline');
      await session.disconnect();
      expect(gateway.deletes, 1);
    },
  );
  test(
    'Backend removal still allows logout when provider revocation fails',
    () async {
      await session.syncUser(testUser);
      gateway.deleteError = Exception('provider');
      await session.disconnect();
      expect(repository.unregistered, ['device-token-001']);
    },
  );
  test(
    'Logout reports a failure if neither revocation path succeeds',
    () async {
      await session.syncUser(testUser);
      gateway.deleteError = Exception('provider');
      repository.unregisterError = Exception('offline');
      await expectLater(session.disconnect(), throwsStateError);
    },
  );
  test(
    'A restored device is unregistered even before its identifier is loaded',
    () async {
      await session.disconnect();
      expect(gateway.deletes, 1);
    },
  );

  Future<ProviderContainer> start(WidgetTester tester) async {
    final auth = FakeAuthRepository()..user = testUser;
    addTearDown(auth.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationSessionProvider.overrideWithValue(session),
          authRepositoryProvider.overrideWithValue(auth),
          tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
          reviewsRepositoryProvider.overrideWithValue(FakeReviewsRepository()),
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository(),
          ),
        ],
        child: const CasaEnJuegoApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(CasaEnJuegoApp)),
    );
  }

  testWidgets(
    'Foreground notices close after three seconds and ignore other recipients',
    (tester) async {
      await start(tester);
      gateway.foreground.add(notice);
      await tester.pumpAndSettle();
      expect(find.text(notice.message), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text(notice.message), findsNothing);
      gateway.foreground.add(
        const PushNotice(
          id: 'other',
          recipientId: 'other-user',
          kind: PushNoticeKind.approved,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );
  testWidgets('Opening a notice navigates to the appropriate protected page', (
    tester,
  ) async {
    final container = await start(tester);
    gateway.opened.add(notice);
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/reviews',
    );
  });
  testWidgets('Cold-start notice waits for restored authentication', (
    tester,
  ) async {
    gateway.initial = const PushNotice(
      id: 'initial',
      recipientId: 'member-id',
      kind: PushNoticeKind.approved,
    );
    final container = await start(tester);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/tasks/activity',
    );
  });
  testWidgets('Opening a reminder returns to tasks instead of activity', (
    tester,
  ) async {
    final container = await start(tester);
    container.read(appRouterProvider).go('/reviews');
    await tester.pumpAndSettle();
    gateway.opened.add(
      const PushNotice(
        id: 'reminder',
        recipientId: 'member-id',
        kind: PushNoticeKind.reminder,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/tasks',
    );
  });
}
