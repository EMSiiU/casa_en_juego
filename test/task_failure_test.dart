import 'package:casa_en_juego/features/tasks/models/task_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Schema failures do not suggest a connection problem', () {
    final message = TaskFailure.messageFor(
      const PostgrestException(
        message: 'column points_snapshot does not exist',
        code: '42703',
      ),
    );
    expect(message, contains('base de datos'));
    expect(message, isNot(contains('conexión')));
  });
  test('Unexpected errors do not assume an internet failure', () {
    expect(
      TaskFailure.messageFor(StateError('Unexpected')),
      isNot(contains('conexión')),
    );
  });
  test('Access failures keep their specific message', () {
    expect(
      TaskFailure.messageFor(
        const PostgrestException(message: 'Denied', code: '42501'),
      ),
      contains('acceso'),
    );
  });
}
