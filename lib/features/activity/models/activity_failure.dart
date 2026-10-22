import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityFailure implements Exception {
  const ActivityFailure(this.message);
  final String message;

  static String messageFor(Object error) {
    if (error is ActivityFailure) return error.message;
    if (error is PostgrestException &&
        (error.code == '42501' || error.code == 'PGRST301')) {
      return 'No pudimos acceder a tu historial. Revisa tu sesión.';
    }
    return 'No pudimos cargar tu actividad. Revisa tu conexión y vuelve a intentarlo.';
  }
}
