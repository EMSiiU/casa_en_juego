enum PushNoticeKind { submitted, approved, rejected, reminder }

class PushNotice {
  const PushNotice({
    required this.id,
    required this.recipientId,
    required this.kind,
  });
  final String id;
  final String recipientId;
  final PushNoticeKind kind;

  static PushNotice? fromData(Map<String, dynamic> data) {
    final kind = PushNoticeKind.values
        .where((kind) => kind.name == data['kind'])
        .firstOrNull;
    final id = data['notification_id'];
    final recipient = data['recipient_id'];
    if (kind == null ||
        id is! String ||
        id.isEmpty ||
        recipient is! String ||
        recipient.isEmpty) {
      return null;
    }
    return PushNotice(id: id, recipientId: recipient, kind: kind);
  }

  String get route => switch (kind) {
    PushNoticeKind.submitted => '/reviews',
    PushNoticeKind.reminder => '/tasks',
    _ => '/tasks/activity',
  };
  String get message => switch (kind) {
    PushNoticeKind.reminder => 'Hoy todavía no tienes tareas pendientes o aprobadas. ¡Anímate a sumar en casa!',
    PushNoticeKind.submitted => 'Hay una nueva tarea por revisar.',
    PushNoticeKind.approved =>
      'Una de tus tareas fue aprobada. ¡Tu esfuerzo suma!',
    PushNoticeKind.rejected =>
      'Una de tus tareas fue rechazada. Consulta tu actividad.',
  };
}

enum PushDeviceStatus {
  unavailable,
  disabled,
  connecting,
  ready,
  denied,
  error,
}
