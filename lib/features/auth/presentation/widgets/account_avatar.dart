import 'package:flutter/foundation.dart';
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
    this.canEditPhoto = false,
    this.localOnly = false,
    this.radius = 20,
  });

  final String name;
  final String? userId;
  final String? avatarUrl;
  final bool canEditPhoto;
  final bool localOnly;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    final url = avatarUrl;
    final photo = id != null && canEditPhoto
        ? ref
              .watch(
                localOnly
                    ? cachedAccountPhotoProvider(id)
                    : accountPhotoProvider(id),
              )
              .value
        : null;
    final providerBytes = photo == null && id != null && url != null && !kIsWeb
        ? ref
              .watch(
                providerAvatarPhotoProvider((
                  userId: id,
                  url: url,
                  localOnly: localOnly,
                )),
              )
              .value
        : null;
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
    final bytes = photo ?? providerBytes;
    final providerPhoto = kIsWeb && url != null && !localOnly
        ? Image.network(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            excludeFromSemantics: true,
            frameBuilder: (context, child, frame, synchronous) =>
                frame != null || synchronous ? child : fallback,
            errorBuilder: (context, error, stack) => fallback,
          )
        : fallback;
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.appColors.primaryContainer,
      foregroundColor: context.appColors.onSurface,
      child: ClipOval(
        child: bytes == null
            ? providerPhoto
            : Image.memory(
                bytes,
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
