import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileFailure implements Exception {
  const ProfileFailure(this.message);
  final String message;
  static String messageFor(Object error) {
    if (error is ProfileFailure) return error.message;
    if (error is PostgrestException) {
      if (error.code == '22023') {
        return 'Escribe un nombre de 1 a 100 caracteres, en una sola línea.';
      }
      return 'No pudimos acceder a tu perfil. Revisa tu sesión o habla con el administrador.';
    }
    return 'No pudimos completar la operación. Inténtalo de nuevo.';
  }
}
