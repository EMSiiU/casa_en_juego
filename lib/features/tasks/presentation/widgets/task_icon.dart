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
    child: iconName == 'sneakers'
        ? Padding(
            padding: EdgeInsets.all(size * 0.20),
            child: const CustomPaint(painter: _SneakerPainter()),
          )
        : Icon(
            switch (iconName) {
              'broom' => Icons.cleaning_services_outlined,
              'utensils' => Icons.restaurant_outlined,
              'bathtub' => Icons.bathtub_outlined,
              'trash' => Icons.delete_outline,
              'droplets' => Icons.water_drop_outlined,
              'window' => Icons.window_outlined,
              'bed' => Icons.bed_outlined,
              'shelf' => Icons.shelves,
              'clothes' => Icons.checkroom_outlined,
              'siblingItems' => Icons.family_restroom_outlined,
              'personalItems' => Icons.inventory_2_outlined,
              _ => Icons.task_alt,
            },
            color: AppTheme.primary,
            size: size * 0.55,
          ),
  );
}

class _SneakerPainter extends CustomPainter {
  const _SneakerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    // Contorno de tenis con suela y agujetas, acorde a los iconos delineados.
    canvas.drawPath(
      Path()
        ..moveTo(3, 6)
        ..lineTo(8, 9)
        ..lineTo(11, 6)
        ..lineTo(15, 12)
        ..lineTo(20, 14)
        ..quadraticBezierTo(22, 15, 22, 17)
        ..lineTo(22, 19)
        ..lineTo(2, 19)
        ..lineTo(2, 11)
        ..close(),
      paint,
    );
    canvas.drawLine(const Offset(2, 16), const Offset(22, 16), paint);
    canvas.drawLine(const Offset(11, 10), const Offset(13, 9), paint);
    canvas.drawLine(const Offset(13, 13), const Offset(15, 12), paint);
  }

  @override
  bool shouldRepaint(covariant _SneakerPainter oldDelegate) => false;
}
