import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/auth_failure.dart';

abstract interface class AuthRepository {
  Stream<AppUser?> watchUser();
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AppUser?> watchUser() {
    // Supabase emite initialSession al suscribirse y restaura la sesión local.
    // Los refrescos de token no vuelven a consultar el mismo perfil.
    return _client.auth.onAuthStateChange
        .map((event) => event.session?.user.id)
        .distinct()
        .asyncMap((userId) async {
          if (userId == null) return null;
          final data = await _client
              .from('users')
              .select('id, name, email, role, notifications_enabled')
              .eq('id', userId)
              .maybeSingle();
          if (data == null) {
            throw const AuthFailure(
              'Tu cuenta no tiene un perfil familiar. Habla con el administrador.',
            );
          }
          return AppUser.fromJson(data);
        });
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.session == null) {
      throw const AuthFailure(
        'No se pudo iniciar la sesión. Inténtalo de nuevo.',
      );
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut(scope: SignOutScope.local);
}
