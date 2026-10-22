import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({super.key});

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: 0,
    onDestinationSelected: (index) {
      if (index == 0) context.go('/tasks');
    },
    // Las demás pestañas se habilitarán al implementar sus respectivas features.
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Tareas',
      ),
      NavigationDestination(
        icon: Icon(Icons.emoji_events_outlined),
        label: 'Ranking',
        enabled: false,
      ),
      NavigationDestination(
        icon: Icon(Icons.check_circle_outline),
        label: 'Revisiones',
        enabled: false,
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        label: 'Perfil',
        enabled: false,
      ),
    ],
  );
}
