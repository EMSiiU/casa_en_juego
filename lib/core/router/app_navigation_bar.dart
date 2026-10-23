import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final count = ref.watch(reviewsInboxProvider).asData?.value.length ?? 0;
    return NavigationBar(
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: (index) {
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
        }
      },
      // Perfil se habilitará al implementar su feature.
      destinations: [
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
            backgroundColor: AppTheme.primary,
            textColor: AppTheme.background,
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(Icons.check_circle_outline),
          ),
          selectedIcon: Badge(
            backgroundColor: AppTheme.primary,
            textColor: AppTheme.background,
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(Icons.check_circle),
          ),
          label: 'Revisiones',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
          enabled: false,
        ),
      ],
    );
  }
}
