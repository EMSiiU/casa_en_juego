enum PushNoticeKind { submitted, approved, rejected, reminder, announcement }

class PushNotice {
  const PushNotice({
    required this.id,
    required this.recipientId,
    required this.kind,
  }) : _announcement = null;

  const PushNotice._general({required this.id, required String text})
    : kind = PushNoticeKind.announcement,
      recipientId = null,
      _announcement = text;

  final String id;
  final String? recipientId;
  final PushNoticeKind kind;
  final String? _announcement;

  static PushNotice? fromData(Map<String, dynamic> data) {
    final kind = PushNoticeKind.values
        .where((kind) => kind.name == data['kind'])
        .firstOrNull;
    final id = data['notification_id'];
    final recipient = data['recipient_id'];
    if (kind == null ||
        kind == PushNoticeKind.announcement ||
        id is! String ||
        id.isEmpty ||
        recipient is! String ||
        recipient.isEmpty) {
      return null;
    }
    return PushNotice(id: id, recipientId: recipient, kind: kind);
  }

  static PushNotice? fromForeground(
    Map<String, dynamic> data, {
    required String? messageId,
    required String? title,
    required String? body,
  }) {
    final privateNotice = fromData(data);
    if (privateNotice != null) return privateNotice;
    // An incomplete private message must not be displayed as a general notice.
    if (data.containsKey('kind') ||
        data.containsKey('recipient_id') ||
        data.containsKey('notification_id')) {
      return null;
    }
    final text = [
      title?.trim(),
      body?.trim(),
    ].whereType<String>().where((part) => part.isNotEmpty).join('\n');
    return text.isEmpty
        ? null
        : PushNotice._general(
            id: messageId ?? 'announcement:$text',
            text: text,
          );
  }

  String get route => switch (kind) {
    PushNoticeKind.submitted => '/reviews',
    PushNoticeKind.reminder || PushNoticeKind.announcement => '/tasks',
    _ => '/tasks/activity',
  };
  String get message => switch (kind) {
    PushNoticeKind.announcement => _announcement!,
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
