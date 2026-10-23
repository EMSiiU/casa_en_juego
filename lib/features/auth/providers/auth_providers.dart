import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_provider.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';
import '../../notifications/providers/notification_providers.dart';
import '../models/auth_failure.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

final currentUserProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchUser(),
  // El usuario decide cuándo reintentar si falla la lectura del perfil.
  retry: (retryCount, error) => null,
);

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> signIn({required String email, required String password}) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password),
    );
    if (ref.mounted) state = result;
  }

  Future<void> signOut() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final session = ref.read(notificationSessionProvider);
    final result = await AsyncValue.guard(() async {
      try {
        await session?.disconnect();
      } catch (_) {
        throw const AuthFailure(
          'No pudimos desvincular los avisos de este dispositivo. Intenta cerrar sesión de nuevo.',
        );
      }
      await ref.read(authRepositoryProvider).signOut();
    });
    if (result.hasError && ref.mounted) {
      await session?.syncUser(
        ref.read(currentUserProvider).asData?.value,
        requestPermission: false,
      );
    }
    if (ref.mounted) state = result;
  }
}
