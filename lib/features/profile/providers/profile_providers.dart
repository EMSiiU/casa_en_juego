import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_provider.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/profile_failure.dart';
import '../models/profile_state.dart';
import '../repositories/profile_repository.dart';
import '../../notifications/providers/notification_providers.dart';

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
    final generation = ++_generation;
    final user = ref.watch(currentUserProvider).asData?.value;
    final repository = ref.watch(profileRepositoryProvider);
    if (user == null) {
      throw const ProfileFailure('Inicia sesión para ver tu perfil.');
    }
    try {
      final loaded = await repository.loadProfile(user.id);
      if (ref.mounted &&
          generation == _generation &&
          ref.read(currentUserProvider).asData?.value?.id == user.id) {
        final session = ref.read(notificationSessionProvider);
        if (session != null) {
          unawaited(session.syncUser(loaded, requestPermission: false));
        }
      }
      return ProfileState(user: loaded);
    } catch (error) {
      _logFailure(error);
      rethrow;
    }
  }

  Future<void> setNotifications(bool enabled) {
    if (state.asData?.value.user.notificationsEnabled == enabled) {
      return Future.value();
    }
    return _save(
      (repository, user) =>
          repository.setNotifications(userId: user.id, enabled: enabled),
      onSaved: (user) async =>
          await ref.read(notificationSessionProvider)?.syncUser(user),
    );
  }

  Future<void> rename(String name) async {
    final trimmed = name.trim();
    if (state.asData?.value.user.name == trimmed) return;
    final pendingWrite = ref.keepAlive();
    try {
      await _save(
        (repository, user) async =>
            user.withName(await repository.rename(trimmed)),
        onSaved: (user) =>
            ref.read(accountNameProvider.notifier).applySavedName(user),
      );
    } finally {
      pendingWrite.close();
    }
  }

  Future<void> _save(
    Future<AppUser> Function(ProfileRepository, AppUser) update, {
    required FutureOr<void> Function(AppUser) onSaved,
  }) async {
    final current = state.asData?.value;
    final userId = ref.read(currentUserProvider).asData?.value?.id;
    if (state.isLoading ||
        current == null ||
        current.isSaving ||
        userId != current.user.id ||
        ref.read(authControllerProvider).isLoading) {
      return;
    }
    final generation = _generation;
    // Publica los cambios solo después de que Supabase confirme el guardado.
    state = AsyncData(ProfileState(user: current.user, isSaving: true));
    try {
      final saved = await update(
        ref.read(profileRepositoryProvider),
        current.user,
      );
      if (!ref.mounted ||
          generation != _generation ||
          ref.read(currentUserProvider).asData?.value?.id != userId) {
        return;
      }
      state = AsyncData(ProfileState(user: saved));
      await onSaved(saved);
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
