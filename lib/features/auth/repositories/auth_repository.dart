import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/auth_failure.dart';
import '../models/provider_avatar.dart';
import 'password_recovery.dart';

abstract interface class AuthRepository {
  Stream<AppUser?> watchUser();
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });
  Future<void> resendSignUpCode(String email);
  Future<void> confirmEmail({required String email, required String code});
  Future<void> requestPasswordReset(String email);
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  });
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AppUser?> watchUser() {
    // Supabase emite initialSession al suscribirse y restaura la sesión local.
    // Los refrescos de token no repiten la consulta si la identidad sigue igual.
    return _client.auth.onAuthStateChange
        .map((event) {
          final user = event.session?.user;
          return user != null && user.emailConfirmedAt != null
              ? (
                  id: user.id,
                  avatarUrl: providerAvatarUrl(user),
                  canEditPhoto: user.appMetadata['provider'] == 'email',
                )
              : null;
        })
        .distinct()
        .asyncMap((identity) async {
          if (identity == null) return null;
          final data = await _readProfile(identity.id);
          if (data == null) {
            throw const AuthFailure(
              'No pudimos cargar tu perfil. Intenta de nuevo.',
            );
          }
          return AppUser.fromJson(
            data,
            avatarUrl: identity.avatarUrl,
            canEditPhoto: identity.canEditPhoto,
          );
        })
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stack, sink) {
              final user = _client.auth.currentUser;
              if (user != null &&
                  user.emailConfirmedAt != null &&
                  (error is http.ClientException ||
                      error is TimeoutException ||
                      error is AuthRetryableFetchException)) {
                final name = user.userMetadata?['name'];
                sink.addError(
                  OfflineProfileFailure(
                    userId: user.id,
                    name: name is String && name.trim().isNotEmpty
                        ? name
                        : user.email ?? '',
                    canEditPhoto: user.appMetadata['provider'] == 'email',
                    avatarUrl: providerAvatarUrl(user),
                  ),
                  stack,
                );
              } else {
                sink.addError(error, stack);
              }
            },
          ),
        );
  }

  // Fetch the full personal row to keep existing sessions usable before the
  // personal accounts migration adds is_household_member.
  Future<Map<String, dynamic>?> _loadProfile(String id) =>
      _client.from('users').select().eq('id', id).maybeSingle();

  Future<Map<String, dynamic>?> _readProfile(String id) async {
    final profile = await _loadProfile(id).timeout(const Duration(seconds: 8));
    if (profile != null) return profile;
    await _client
        .rpc('ensure_personal_profile')
        .timeout(const Duration(seconds: 8));
    return _loadProfile(id).timeout(const Duration(seconds: 8));
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
    if (response.user?.emailConfirmedAt == null) {
      await signOut();
      throw const AuthFailure('Confirma tu correo para entrar.');
    }
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    if (response.session != null) {
      await signOut();
      throw const AuthFailure(
        'El registro necesita la confirmación de correo activada.',
      );
    }
  }

  @override
  Future<void> resendSignUpCode(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  @override
  Future<void> confirmEmail({
    required String email,
    required String code,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.email,
    );
    if (response.session == null) {
      throw const AuthFailure(
        'No se abrió una sesión. Si el correo ya está confirmado, inicia sesión.',
      );
    }
  }

  @override
  Future<void> requestPasswordReset(String email) =>
      const PasswordRecovery().sendCode(email);

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) => const PasswordRecovery().reset(
    email: email,
    code: code,
    password: password,
  );

  @override
  Future<void> signOut() => _client.auth.signOut(scope: SignOutScope.local);
}
