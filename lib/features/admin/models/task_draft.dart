import 'admin_failure.dart';

enum TaskIconOption {
  broom('Escoba'),
  utensils('Platos'),
  bathtub('Baño'),
  trash('Basura'),
  droplets('Gotas'),
  window('Ventana');

  const TaskIconOption(this.label);
  final String label;
}

class TaskDraft {
  TaskDraft({
    required String name,
    required this.points,
    required this.iconName,
    required this.isActive,
  }) : name = name.trim() {
    if (this.name.isEmpty || this.name.length > 100) {
      throw const AdminFailure(
        'El nombre debe tener entre 1 y 100 caracteres.',
      );
    }
    if (points < 1 || points > 2147483647) {
      throw const AdminFailure(
        'Los puntos deben ser un entero positivo válido.',
      );
    }
    if (!TaskIconOption.values.any((option) => option.name == iconName)) {
      throw const AdminFailure('Selecciona un ícono de tarea.');
    }
  }
  final String name;
  final int points;
  final String iconName;
  final bool isActive;
  Map<String, dynamic> toJson() => {
    'name': name,
    'points': points,
    'icon_name': iconName,
    'is_active': isActive,
  };
}
