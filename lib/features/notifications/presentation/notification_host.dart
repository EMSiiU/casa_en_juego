import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../activity/providers/activity_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../leaderboard/providers/leaderboard_providers.dart';
import '../../reviews/providers/reviews_providers.dart';
import '../../tasks/providers/tasks_providers.dart';
import '../models/push_notice.dart';
import '../providers/notification_providers.dart';
import '../services/notification_session.dart';

class NotificationHost extends ConsumerStatefulWidget {
  const NotificationHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends ConsumerState<NotificationHost> {
  AppLifecycleListener? _lifecycle;
  NotificationSession? _session;
  PushNotice? _pendingNotice;
  final Set<String> _displayed = {};

  @override
  void initState() {
    super.initState();
    final session = ref.read(notificationSessionProvider);
    _session = session;
    if (session == null) return;
    session.onNotice = _onNotice;
    session.start();
    ref.listenManual(currentUserProvider, (previous, next) {
      if (next.isLoading || next.hasError) return;
      final user = next.asData?.value;
      unawaited(session.syncUser(user));
      final pending = _pendingNotice;
      if (user != null && pending != null) {
        _pendingNotice = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onNotice(pending, true);
        });
      }
    }, fireImmediately: true);
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final user = ref.read(currentUserProvider).asData?.value;
        if (user == null) return;
        unawaited(
          session.syncUser(
            session.user?.id == user.id ? session.user : user,
            requestPermission: false,
          ),
        );
      },
    );
  }

  void _onNotice(PushNotice notice, bool opened) {
    if (!mounted) return;
    final auth = ref.read(currentUserProvider);
    final user = auth.asData?.value;
    if (user == null) {
      if (opened) _pendingNotice = notice;
      return;
    }
    final sessionUser = ref.read(notificationSessionProvider)?.user;
    if (notice.recipientId != user.id ||
        !(sessionUser?.notificationsEnabled ?? user.notificationsEnabled)) {
      return;
    }
    ref.invalidate(tasksDashboardProvider);
    ref.invalidate(reviewsInboxProvider);
    ref.invalidate(leaderboardProvider);
    ref.invalidate(activityProvider);
    final router = ref.read(appRouterProvider);
    if (opened) {
      router.go(notice.route);
      return;
    }
    if (!_displayed.add(notice.id)) return;
    if (_displayed.length > 100) _displayed.remove(_displayed.first);
    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        persist: false,
        content: Text(notice.message),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () {
            if (ref.read(currentUserProvider).asData?.value?.id ==
                notice.recipientId) {
              router.go(notice.route);
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _session?.onNotice = null;
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
