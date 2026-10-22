import 'package:supabase_flutter/supabase_flutter.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  static String messageFor(Object error) {
    if (error is AuthFailure) return error.message;
    if (error is AuthException) {
      return switch (error.code) {
        'invalid_credentials' => 'El correo o la contraseña son incorrectos.',
        'email_not_confirmed' =>
          'Tu correo aún no está confirmado. Habla con el administrador.',
        'over_request_rate_limit' || 'over_email_send_rate_limit' =>
          'Demasiados intentos. Espera unos minutos y vuelve a intentarlo.',
        'user_banned' =>
          'Tu acceso está deshabilitado. Habla con el administrador.',
        _ => 'No pudimos completar el acceso. Inténtalo de nuevo.',
      };
    }
    return 'No pudimos conectar. Revisa tu conexión e inténtalo de nuevo.';
  }
}
