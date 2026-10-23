import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardFailure implements Exception {
  const LeaderboardFailure(this.message);
  final String message;
  static String messageFor(Object error) {
    if (error is LeaderboardFailure) return error.message;
    if (error is PostgrestException) {
      return 'No pudimos consultar el ranking en la base de datos. Revisa tu sesión o habla con el administrador.';
    }
    return 'No pudimos cargar el ranking. Inténtalo de nuevo.';
  }
}
