import 'package:supabase_flutter/supabase_flutter.dart';

class TaskFailure implements Exception {
  const TaskFailure(this.message);
  final String message;

  static String messageFor(Object error, {bool submitting = false}) {
    if (error is TaskFailure) return error.message;
    if (error is PostgrestException) {
      if (error.code == 'P0001') {
        return 'El ciclo terminó o la tarea ya no está disponible. Actualiza el inicio.';
      }
      if (error.code == '42501' || error.code == 'PGRST301') {
        return 'No tienes acceso para esta acción. Revisa tu sesión.';
      }
    }
    return submitting
        ? 'No pudimos confirmar el envío. Actualiza el inicio antes de volver a enviarlo.'
        : 'No pudimos cargar tus tareas. Revisa tu conexión y vuelve a intentarlo.';
  }
}
