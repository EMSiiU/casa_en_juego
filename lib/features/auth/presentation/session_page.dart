import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_failure.dart';
import '../providers/auth_providers.dart';
import 'widgets/account_avatar.dart';

class SessionPage extends ConsumerWidget {
  const SessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final action = ref.watch(authControllerProvider);
    final error = user.error;
    final offline = error is OfflineProfileFailure ? error : null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: user.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (offline != null) ...[
                        AccountAvatar(
                          name: offline.name,
                          userId: offline.userId,
                          avatarUrl: offline.avatarUrl,
                          canEditPhoto: offline.canEditPhoto,
                          localOnly: true,
                          radius: 42,
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        AuthFailure.messageFor(user.error!),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: action.isLoading
                            ? null
                            : () => ref.invalidate(currentUserProvider),
                        child: const Text('Reintentar'),
                      ),
                      TextButton(
                        onPressed: action.isLoading
                            ? null
                            : () => ref
                                  .read(authControllerProvider.notifier)
                                  .signOut(),
                        child: const Text('Cerrar sesión'),
                      ),
                      if (action.hasError)
                        Text(AuthFailure.messageFor(action.error!)),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
