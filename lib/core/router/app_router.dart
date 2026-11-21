import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/presentation/activity_page.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/email_account_page.dart';
import '../../features/auth/presentation/session_page.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/tasks/presentation/tasks_page.dart';
import '../../features/reviews/presentation/reviews_page.dart';
import '../../features/leaderboard/presentation/leaderboard_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/admin/presentation/admin_page.dart';
import '../../features/admin/presentation/cycle_history_page.dart';
import '../../features/admin/presentation/task_catalog_page.dart';
import '../../features/admin/presentation/task_editor_page.dart';
import '../../features/plans/presentation/plans_page.dart';
import '../theme/app_page_bar.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(currentUserProvider, (previous, next) => refresh.refresh());
  final router = GoRouter(
    initialLocation: '/tasks',
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final path = state.uri.path;
      final isEmailPage =
          path == '/login' || path == '/registro' || path == '/recuperar';
      // Mantiene Perfil o Administración al recargar una identidad conocida.
      if ((path == '/admin' || path == '/profile') &&
          user.isLoading &&
          user.value != null &&
          !user.hasError) {
        return null;
      }
      // No se muestran rutas protegidas mientras se restaura o valida el perfil.
      if (user.isLoading || user.hasError) {
        return path == '/session' ? null : '/session';
      }
      if (user.asData?.value == null) {
        return isEmailPage ? null : '/login';
      }
      if (user.asData?.value?.isHouseholdMember == false) {
        final isAccountPage =
            path == '/profile' ||
            path == '/plans' ||
            path == '/admin' ||
            path == '/tasks/activity' ||
            path == '/profile/ciclos' ||
            path.startsWith('/profile/ciclos/');
        return isAccountPage ? null : '/profile';
      }
      if ((path == '/admin' || path.startsWith('/admin/')) &&
          user.asData?.value?.isAdmin != true) {
        return '/profile';
      }
      if (isEmailPage || path == '/session' || path == '/') {
        return '/tasks';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/plans',
        name: 'plans',
        builder: (context, state) => const PlansPage(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminPage(),
        routes: [
          GoRoute(
            path: 'tasks',
            name: 'adminTasks',
            builder: (context, state) => const TaskCatalogPage(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'adminNewTask',
                builder: (context, state) => const TaskEditorPage(),
              ),
              GoRoute(
                path: ':taskId',
                name: 'adminEditTask',
                builder: (context, state) =>
                    TaskEditorPage(taskId: state.pathParameters['taskId']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
        routes: [
          GoRoute(
            path: 'ciclos',
            name: 'cycleHistory',
            builder: (context, state) => const CycleHistoryPage(),
            routes: [
              GoRoute(
                path: ':cycleId',
                name: 'closedCycle',
                builder: (context, state) =>
                    CycleHistoryPage(cycleId: state.pathParameters['cycleId']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/leaderboard',
        name: 'leaderboard',
        builder: (context, state) => const LeaderboardPage(),
      ),
      GoRoute(
        path: '/reviews',
        name: 'reviews',
        builder: (context, state) => const ReviewsPage(),
      ),
      GoRoute(path: '/', redirect: (context, state) => '/tasks'),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/registro',
        builder: (context, state) => EmailAccountPage(
          recovery: false,
          initialEmail: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/recuperar',
        builder: (context, state) => EmailAccountPage(
          recovery: true,
          initialEmail: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/session',
        name: 'session',
        builder: (context, state) => const SessionPage(),
      ),
      GoRoute(
        path: '/tasks',
        name: 'tasks',
        builder: (context, state) => const TasksPage(),
        routes: [
          GoRoute(
            path: 'activity',
            name: 'activity',
            builder: (context, state) => ActivityPage(
              fromProfile: state.uri.queryParameters['from'] == 'profile',
              showSubmissionNotice:
                  state.uri.queryParameters['submitted'] == 'true',
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: const AppPageBar(title: 'Casa en Juego'),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Volver al inicio'),
        ),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}
