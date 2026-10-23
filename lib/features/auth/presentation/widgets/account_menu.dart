import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/auth_failure.dart';
import '../../providers/auth_providers.dart';

class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final authAction = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            persist: false,
            content: Text(AuthFailure.messageFor(next.error!)),
          ),
        );
      }
    });
    final name = user?.name ?? '';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();

    return PopupMenuButton<String>(
      tooltip: 'Abrir cuenta',
      enabled: !authAction.isLoading,
      onSelected: (_) => ref.read(authControllerProvider.notifier).signOut(),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(user?.isAdmin == true ? 'Administrador' : 'Miembro'),
        ),
        const PopupMenuItem(value: 'signOut', child: Text('Cerrar sesión')),
      ],
      child: CircleAvatar(
        backgroundColor: const Color(0xFF39334F),
        foregroundColor: Colors.white,
        child: authAction.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                initials,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
