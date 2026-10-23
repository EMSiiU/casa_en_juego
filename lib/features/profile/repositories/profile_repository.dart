import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/models/app_user.dart';
import '../models/profile_failure.dart';

abstract interface class ProfileRepository {
  Future<AppUser> loadProfile(String userId);
  Future<AppUser> setNotifications({
    required String userId,
    required bool enabled,
  });
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);
  final SupabaseClient _client;
  static const _columns = 'id, name, email, role, notifications_enabled';

  @override
  Future<AppUser> loadProfile(String userId) async {
    final row = await _client
        .from('users')
        .select(_columns)
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      throw const ProfileFailure(
        'Tu perfil no está disponible. Habla con el administrador.',
      );
    }
    return AppUser.fromJson(row);
  }

  @override
  Future<AppUser> setNotifications({
    required String userId,
    required bool enabled,
  }) async {
    // RLS y el permiso por columna limitan el cambio a la preferencia del usuario.
    final row = await _client
        .from('users')
        .update({'notifications_enabled': enabled})
        .eq('id', userId)
        .select(_columns)
        .maybeSingle();
    if (row == null) {
      throw const ProfileFailure(
        'No pudimos guardar tu preferencia. Revisa tu sesión.',
      );
    }
    return AppUser.fromJson(row);
  }
}
