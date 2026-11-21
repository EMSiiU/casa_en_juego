import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/reviews/providers/reviews_providers.dart';
import '../../features/leaderboard/providers/leaderboard_providers.dart';
import '../../features/tasks/providers/tasks_providers.dart';
import '../theme/app_theme.dart';

class AppNavigationBar extends ConsumerStatefulWidget {
  const AppNavigationBar({super.key, this.selectedIndex = 0});
  final int selectedIndex;

  @override
  ConsumerState<AppNavigationBar> createState() => _AppNavigationBarState();
}

class _AppNavigationBarState extends ConsumerState<AppNavigationBar> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(reviewsInboxProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCycle =
        ref.watch(currentUserProvider).asData?.value?.isHouseholdMember ?? true;
    final count = hasCycle
        ? ref.watch(reviewsInboxProvider).asData?.value.length ?? 0
        : 0;
    return NavigationBar(
      selectedIndex: hasCycle
          ? widget.selectedIndex
          : (widget.selectedIndex == 4 ? 1 : 0),
      onDestinationSelected: (destination) {
        final index = hasCycle ? destination : destination + 3;
        if (index == 0) {
          ref.invalidate(reviewsInboxProvider);
          ref.invalidate(tasksDashboardProvider);
          context.go('/tasks');
        } else if (index == 1) {
          ref.invalidate(leaderboardProvider);
          context.go('/leaderboard');
        } else if (index == 2) {
          ref.invalidate(reviewsInboxProvider);
          context.go('/reviews');
        } else if (index == 3) {
          context.go('/profile');
        } else if (index == 4) {
          context.go('/plans');
        }
      },
      destinations: [
        if (hasCycle) ...[
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Tareas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Ranking',
            selectedIcon: Icon(Icons.emoji_events),
          ),
          NavigationDestination(
            icon: Badge(
              backgroundColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: const Icon(Icons.check_circle_outline),
            ),
            selectedIcon: Badge(
              backgroundColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: const Icon(Icons.check_circle),
            ),
            label: 'Revisiones',
          ),
        ],
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
          selectedIcon: Icon(Icons.person),
        ),
        const NavigationDestination(
          icon: Icon(Icons.workspace_premium_outlined),
          selectedIcon: Icon(Icons.workspace_premium),
          label: 'Planes',
        ),
      ],
    );
  }
}
