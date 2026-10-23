import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/profile_failure.dart';
import '../models/profile_state.dart';
import '../repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);
final profileProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, ProfileState>(
      ProfileController.new,
      retry: (retryCount, error) => null,
    );

class ProfileController extends AsyncNotifier<ProfileState> {
  int _generation = 0;

  @override
  Future<ProfileState> build() async {
    _generation++;
    final user = ref.watch(currentUserProvider).asData?.value;
    final repository = ref.watch(profileRepositoryProvider);
    if (user == null) {
      throw const ProfileFailure('Inicia sesión para ver tu perfil.');
    }
    try {
      return ProfileState(user: await repository.loadProfile(user.id));
    } catch (error) {
      _logFailure(error);
      rethrow;
    }
  }

  Future<void> setNotifications(bool enabled) async {
    final current = state.asData?.value;
    final userId = ref.read(currentUserProvider).asData?.value?.id;
    if (state.isLoading ||
        current == null ||
        current.isSaving ||
        userId != current.user.id ||
        ref.read(authControllerProvider).isLoading ||
        enabled == current.user.notificationsEnabled) {
      return;
    }
    final generation = _generation;
    // El interruptor solo cambia cuando Supabase confirma que guardó la preferencia.
    state = AsyncData(ProfileState(user: current.user, isSaving: true));
    try {
      final saved = await ref
          .read(profileRepositoryProvider)
          .setNotifications(userId: current.user.id, enabled: enabled);
      if (!ref.mounted ||
          generation != _generation ||
          ref.read(currentUserProvider).asData?.value?.id != userId) {
        return;
      }
      state = AsyncData(ProfileState(user: saved));
    } catch (error) {
      if (!ref.mounted ||
          generation != _generation ||
          ref.read(currentUserProvider).asData?.value?.id != userId) {
        return;
      }
      _logFailure(error);
      state = AsyncData(
        ProfileState(
          user: current.user,
          errorMessage: ProfileFailure.messageFor(error),
        ),
      );
    }
  }

  void _logFailure(Object error) {
    if (kDebugMode) {
      // Solo se registra la clase o el código del error, sin datos personales.
      debugPrint(
        'profile.operation failed: ${error is PostgrestException ? error.code : error.runtimeType}',
      );
    }
  }
}
