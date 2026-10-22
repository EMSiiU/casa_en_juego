import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewFailure implements Exception {
  const ReviewFailure(this.message);
  final String message;

  static String messageFor(Object error, {bool deciding = false}) {
    if (error is ReviewFailure) return error.message;
    if (error is PostgrestException) {
      if (error.code == 'P0001') {
        return 'La solicitud ya fue resuelta o el ciclo terminó. Actualiza la bandeja.';
      }
      if (error.code == '42501' || error.code == 'PGRST301') {
        return 'No tienes permiso para revisar esta solicitud. Revisa tu sesión.';
      }
      return 'La base de datos no pudo completar la operación. Habla con el administrador.';
    }
    return deciding
        ? 'No pudimos confirmar la decisión. Actualiza la bandeja antes de volver a intentarlo.'
        : 'No pudimos cargar las revisiones. Inténtalo de nuevo.';
  }
}
