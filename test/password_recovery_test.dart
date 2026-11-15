import 'dart:convert';

import 'package:casa_en_juego/features/auth/repositories/password_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'A recovery code authorizes a password change and closes the session',
    () async {
      final calls = <String>[];
      await http.runWithClient(
        () async {
          const recovery = PasswordRecovery();
          await recovery.sendCode('elena@example.com');
          await recovery.reset(
            email: 'elena@example.com',
            code: '123456',
            password: 'replacement-password',
          );
        },
        () => MockClient((request) async {
          final endpoint = request.url.pathSegments.last;
          calls.add('${request.method} $endpoint');
          switch (endpoint) {
            case 'recover':
              expect(jsonDecode(request.body), {'email': 'elena@example.com'});
              return http.Response('{}', 200);
            case 'verify':
              expect(jsonDecode(request.body), {
                'email': 'elena@example.com',
                'token': '123456',
                'type': 'recovery',
              });
              return http.Response('{"access_token":"temporary"}', 200);
            case 'user':
              expect(request.headers['authorization'], 'Bearer temporary');
              expect(jsonDecode(request.body), {
                'password': 'replacement-password',
              });
              return http.Response('{}', 200);
            case 'logout':
              expect(request.headers['authorization'], 'Bearer temporary');
              expect(request.url.queryParameters['scope'], 'local');
              return http.Response('', 204);
            default:
              fail('Unexpected recovery endpoint: $endpoint');
          }
        }),
      );
      expect(calls, ['POST recover', 'POST verify', 'PUT user', 'POST logout']);
    },
  );

  test('An expired code cannot reach the password update step', () async {
    await http.runWithClient(
      () => expectLater(
        const PasswordRecovery().reset(
          email: 'elena@example.com',
          code: '000000',
          password: 'replacement-password',
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.code,
            'code',
            'otp_expired',
          ),
        ),
      ),
      () => MockClient((request) async {
        expect(request.url.pathSegments.last, 'verify');
        return http.Response('{"error_code":"otp_expired"}', 403);
      }),
    );
  });
}
