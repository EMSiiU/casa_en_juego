import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 20,
  });

  final String name;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(fontSize: radius * 0.65, fontWeight: FontWeight.bold),
      ),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.appColors.primaryContainer,
      foregroundColor: context.appColors.onSurface,
      child: avatarUrl == null
          ? fallback
          : ClipOval(
              child: Image.network(
                avatarUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, synchronous) =>
                    frame != null || synchronous ? child : fallback,
                errorBuilder: (context, error, stack) => fallback,
              ),
            ),
    );
  }
}
