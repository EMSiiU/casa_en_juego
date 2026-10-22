import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class TaskIcon extends StatelessWidget {
  const TaskIcon({super.key, required this.iconName, this.size = 36});
  final String iconName;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(
      switch (iconName) {
        'broom' => Icons.cleaning_services_outlined,
        'utensils' => Icons.restaurant_outlined,
        'bathtub' => Icons.bathtub_outlined,
        'trash' => Icons.delete_outline,
        'droplets' => Icons.water_drop_outlined,
        'window' => Icons.window_outlined,
        _ => Icons.task_alt,
      },
      color: AppTheme.primary,
      size: size * 0.55,
    ),
  );
}
