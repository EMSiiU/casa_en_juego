import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_providers.dart';

class SocialSignInButtons extends ConsumerWidget {
  const SocialSignInButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(authControllerProvider).isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => ref
                    .read(authControllerProvider.notifier)
                    .signInWithProvider(OAuthProvider.google),
          child: const Text('Continuar con Google'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => ref
                    .read(authControllerProvider.notifier)
                    .signInWithProvider(OAuthProvider.github),
          child: const Text('Continuar con GitHub'),
        ),
      ],
    );
  }
}
