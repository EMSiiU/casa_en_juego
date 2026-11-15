import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/account_photo_providers.dart';

class AccountAvatar extends ConsumerWidget {
  const AccountAvatar({
    super.key,
    required this.name,
    this.userId,
    this.avatarUrl,
    this.radius = 20,
  });

  final String name;
  final String? userId;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = userId == null
        ? null
        : ref.watch(accountPhotoProvider(userId!)).value;
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
    final providerPhoto = avatarUrl == null
        ? fallback
        : Image.network(
            avatarUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            excludeFromSemantics: true,
            frameBuilder: (context, child, frame, synchronous) =>
                frame != null || synchronous ? child : fallback,
            errorBuilder: (context, error, stack) => fallback,
          );
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.appColors.primaryContainer,
      foregroundColor: context.appColors.onSurface,
      child: ClipOval(
        child: photo == null
            ? providerPhoto
            : Image.memory(
                photo,
                width: radius * 2,
                height: radius * 2,
                cacheWidth: 256,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, synchronous) =>
                    frame != null || synchronous ? child : providerPhoto,
                errorBuilder: (context, error, stack) => providerPhoto,
              ),
      ),
    );
  }
}
