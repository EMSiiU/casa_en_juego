import 'package:supabase_flutter/supabase_flutter.dart';

class AdminFailure implements Exception {
  const AdminFailure(this.message);
  final String message;
  static String messageFor(Object error) {
    if (error is AdminFailure) return error.message;
    if (error is PostgrestException) {
      return switch (error.code) {
        '23505' =>
          'Ya existe un ciclo activo. Actualiza el panel antes de continuar.',
        '42501' ||
        'PGRST301' => 'Esta acción requiere una cuenta de administrador.',
        'P0001' => 'El ciclo ya cambió o la operación no está permitida. Actualiza el panel.',
        _ => 'La base de datos no pudo completar la operación. Habla con el administrador.',
      };
    }
    return 'No pudimos confirmar la operación. Actualiza los datos antes de volver a intentarlo.';
  }
}
