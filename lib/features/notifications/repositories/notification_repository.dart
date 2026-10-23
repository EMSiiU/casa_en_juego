import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class NotificationRepository {
  Future<void> register({required String token, required String platform});
  Future<void> unregister(String token);
}

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);
  final SupabaseClient _client;
  @override
  Future<void> register({
    required String token,
    required String platform,
  }) async {
    // El usuario se obtiene del JWT en el servidor, nunca de un parámetro del cliente.
    await _client.rpc(
      'register_push_device',
      params: {'p_token': token, 'p_platform': platform},
    );
  }

  @override
  Future<void> unregister(String token) async {
    await _client.rpc('unregister_push_device', params: {'p_token': token});
  }
}
