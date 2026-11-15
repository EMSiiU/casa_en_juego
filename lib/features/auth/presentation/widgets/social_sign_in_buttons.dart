import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_providers.dart';

class SocialSignInButtons extends ConsumerWidget {
  const SocialSignInButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(authControllerProvider).isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => ref
                    .read(authControllerProvider.notifier)
                    .signInWithProvider(OAuthProvider.google),
          icon: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Image.asset(
                'assets/brand/google-g.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ),
          label: const Text('Continuar con Google'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => ref
                    .read(authControllerProvider.notifier)
                    .signInWithProvider(OAuthProvider.github),
          icon: Image.asset(
            isDark
                ? 'assets/brand/github-white.png'
                : 'assets/brand/github-black.png',
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          label: const Text('Continuar con GitHub'),
        ),
      ],
    );
  }
}
