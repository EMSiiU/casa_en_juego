import 'package:supabase_flutter/supabase_flutter.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  static String messageFor(Object error) {
    if (error is AuthFailure) return error.message;
    if (error is AuthException) {
      return switch (error.code) {
        'invalid_credentials' => 'El correo o la contraseña son incorrectos.',
        'email_not_confirmed' => 'Tu correo aún no está confirmado. Abre Crear cuenta para confirmar o reenviar el código.',
        'otp_expired' =>
          'El código es incorrecto o venció. Solicita uno nuevo.',
        'weak_password' => 'Elige una contraseña más segura.',
        'same_password' => 'Elige una contraseña diferente a la anterior.',
        'signup_disabled' => 'El registro de cuentas aún no está habilitado.',
        'provider_disabled' =>
          'Este proveedor de acceso aún no está habilitado.',
        'provider_email_needs_verification' => 'Verifica el correo de tu cuenta con el proveedor antes de continuar.',
        'access_denied' =>
          'El acceso con el proveedor se canceló o fue rechazado.',
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
