import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileFailure implements Exception {
  const ProfileFailure(this.message);
  final String message;
  static String messageFor(Object error) {
    if (error is ProfileFailure) return error.message;
    if (error is PostgrestException) {
      if (error.message == 'CYCLE_DETAILS_INVALID') {
        return 'Revisa el nombre y elige una fecha de fin prevista.';
      }
      if (error.message == 'CYCLE_END_DATE_INVALID') {
        return 'Elige una fecha posterior al día de inicio en Ciudad de México.';
      }
      if (error.message == 'CYCLE_PROFILE_UNAVAILABLE') {
        return 'Inicia sesión con tu correo confirmado para crear un ciclo.';
      }
      if (error.code == '22023') {
        return 'Escribe un nombre de 1 a 100 caracteres, en una sola línea.';
      }
      return 'No pudimos acceder a tu perfil. Revisa tu sesión o habla con el administrador.';
    }
    return 'No pudimos completar la operación. Inténtalo de nuevo.';
  }
}
