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
      if ([
        '42703',
        '42P01',
        'PGRST200',
        'PGRST204',
        'PGRST205',
      ].contains(error.code)) {
        return 'La base de datos no coincide con la configuración de la app. Habla con el administrador.';
      }
      return submitting
          ? 'La base de datos no pudo registrar la solicitud. Actualiza el inicio antes de volver a enviarla.'
          : 'La base de datos no pudo cargar las tareas. Inténtalo de nuevo o habla con el administrador.';
    }
    if (error is FormatException || error is TypeError) {
      return 'Los datos recibidos no tienen el formato esperado. Habla con el administrador.';
    }
    return submitting
        ? 'No pudimos confirmar el envío. Actualiza el inicio antes de volver a enviarlo.'
        : 'No pudimos cargar tus tareas. Inténtalo de nuevo.';
  }
}
