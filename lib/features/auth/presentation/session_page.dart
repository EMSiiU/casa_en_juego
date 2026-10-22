import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_failure.dart';
import '../providers/auth_providers.dart';

class SessionPage extends ConsumerWidget {
  const SessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final action = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: user.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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

// Destino temporal para verificar el acceso hasta implementar la feature tasks.
class AuthenticatedPage extends ConsumerWidget {
  const AuthenticatedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final action = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Casa en Juego')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¡Hola, ${user?.name ?? ''}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(user?.isAdmin == true ? 'Administrador' : 'Miembro'),
                const SizedBox(height: 12),
                const Text(
                  'Tu sesión está lista. Pronto podrás registrar tus tareas.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: action.isLoading
                      ? null
                      : () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                  child: Text(
                    action.isLoading ? 'Cerrando sesión…' : 'Cerrar sesión',
                  ),
                ),
                if (action.hasError) ...[
                  const SizedBox(height: 12),
                  Text(AuthFailure.messageFor(action.error!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
