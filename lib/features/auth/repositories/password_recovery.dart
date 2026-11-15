import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_config.dart';
import '../models/auth_failure.dart';

// Use isolated requests so a recovery session is neither persisted nor
// broadcast by the regular Supabase Auth client in the browser.
class PasswordRecovery {
  const PasswordRecovery();

  static const _timeout = Duration(seconds: 20);

  Map<String, String> _headers([String? token]) => {
    'apikey': SupabaseConfig.publishableKey,
    'Authorization': 'Bearer ${token ?? SupabaseConfig.publishableKey}',
    'Content-Type': 'application/json',
    'X-Supabase-Api-Version': '2024-01-01',
  };

  Uri _endpoint(String action, {Map<String, String>? query}) {
    final base = Uri.parse(SupabaseConfig.url);
    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((part) => part.isNotEmpty),
        'auth',
        'v1',
        action,
      ],
      queryParameters: query,
    );
  }

  Future<void> sendCode(String email) async {
    final response = await http
        .post(
          _endpoint('recover'),
          headers: _headers(),
          body: jsonEncode({'email': email}),
        )
        .timeout(_timeout);
    _checkResponse(response);
  }

  Future<void> reset({
    required String email,
    required String code,
    required String password,
  }) async {
    final challenge = await http
        .post(
          _endpoint('verify'),
          headers: _headers(),
          body: jsonEncode({'email': email, 'token': code, 'type': 'recovery'}),
        )
        .timeout(_timeout);
    _checkResponse(challenge);
    final token =
        (jsonDecode(challenge.body) as Map<String, dynamic>)['access_token'];
    if (token is! String || token.isEmpty) {
      throw const AuthFailure(
        'No pudimos validar el código. Solicita uno nuevo.',
      );
    }

    try {
      final response = await http
          .put(
            _endpoint('user'),
            headers: _headers(token),
            body: jsonEncode({'password': password}),
          )
          .timeout(_timeout);
      _checkResponse(response);
    } catch (error) {
      throw AuthFailure(
        '${AuthFailure.messageFor(error)} Si el código ya no funciona, solicita uno nuevo.',
      );
    } finally {
      try {
        await http
            .post(
              _endpoint('logout', query: {'scope': 'local'}),
              headers: _headers(token),
            )
            .timeout(_timeout);
      } catch (_) {
        // The short-lived recovery token stays in memory only.
      }
    }
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw const AuthFailure(
        'El servicio de correo no está disponible. Intenta de nuevo.',
      );
    }
    final code = body is Map
        ? (body['error_code'] ?? body['code'])?.toString()
        : null;
    throw AuthException('Error de autenticación', code: code);
  }
}
