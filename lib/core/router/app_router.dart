import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/presentation/activity_page.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/session_page.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/tasks/presentation/tasks_page.dart';
import '../../features/reviews/presentation/reviews_page.dart';
import '../../features/leaderboard/presentation/leaderboard_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/admin/presentation/admin_page.dart';
import '../../features/admin/presentation/task_catalog_page.dart';
import '../../features/admin/presentation/task_editor_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(currentUserProvider, (previous, next) => refresh.refresh());
  final router = GoRouter(
    initialLocation: '/tasks',
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final path = state.uri.path;
      // No se muestran rutas protegidas mientras se restaura o valida el perfil.
      if (user.isLoading || user.hasError) {
        return path == '/session' ? null : '/session';
      }
      if (user.asData?.value == null) {
        return path == '/login' ? null : '/login';
      }
      if ((path == '/admin' || path.startsWith('/admin/')) &&
          user.asData?.value?.isAdmin != true) {
        return '/profile';
      }
      if (path == '/login' || path == '/session' || path == '/') {
        return '/tasks';
      }
      return null;
    },
    routes: [
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
      appBar: AppBar(title: const Text('Casa en Juego')),
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
