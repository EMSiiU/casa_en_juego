import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/app_user.dart';
import '../models/push_notice.dart';
import '../providers/notification_providers.dart';

class NotificationStatusTile extends ConsumerWidget {
  const NotificationStatusTile({super.key, required this.user});
  final AppUser user;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!user.notificationsEnabled) return const SizedBox.shrink();
    final status = ref.watch(pushDeviceStatusProvider).asData?.value;
    if (status == null || status == PushDeviceStatus.disabled) {
      return const SizedBox.shrink();
    }
    final message = switch (status) {
      PushDeviceStatus.denied => 'Permite las notificaciones en los ajustes del teléfono y vuelve a intentar.',
      PushDeviceStatus.error =>
        'No pudimos activar los avisos en este dispositivo.',
      PushDeviceStatus.unavailable =>
        'Los avisos no están disponibles en este dispositivo.',
      PushDeviceStatus.connecting => 'Activando avisos…',
      PushDeviceStatus.ready => 'Avisos activos en este dispositivo.',
      PushDeviceStatus.disabled => '',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          if ([
            PushDeviceStatus.denied,
            PushDeviceStatus.error,
          ].contains(status))
            TextButton(
              onPressed: () =>
                  ref.read(notificationSessionProvider)?.syncUser(user),
              child: const Text('Reintentar avisos'),
            ),
        ],
      ),
    );
  }
}
