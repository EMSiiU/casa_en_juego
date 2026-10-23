import 'dart:convert';
import 'dart:io';

import 'package:casa_en_juego/features/profile/models/profile_failure.dart';
import 'package:casa_en_juego/features/profile/repositories/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseProfileRepository repository;
  late List<Uri> requests;
  late List<Map<String, dynamic>> updates;
  bool missing = false;
  bool enabled = true;
  setUp(() async {
    requests = [];
    updates = [];
    missing = false;
    enabled = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri);
      if (request.method == 'PATCH') {
        final values = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        updates.add(values);
        enabled = values['notifications_enabled'] as bool;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          missing
              ? null
              : {
                  'id': 'member-id',
                  'name': 'Ana',
                  'email': 'ana@familia.es',
                  'role': 'sibling',
                  'notifications_enabled': enabled,
                },
        ),
      );
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-public-key',
    );
    repository = SupabaseProfileRepository(client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('Profile reads only the user selected by session id', () async {
    final user = await repository.loadProfile('member-id');
    expect(requests.single.queryParameters['id'], 'eq.member-id');
    expect(user.name, 'Ana');
    expect(user.notificationsEnabled, isTrue);
  });
  test('Preference updates send only notifications_enabled and persist across reads', () async {
    final user = await repository.setNotifications(
      userId: 'member-id',
      enabled: false,
    );
    expect(updates.single, {'notifications_enabled': false});
    expect(requests.first.queryParameters['id'], 'eq.member-id');
    expect(user.notificationsEnabled, isFalse);
    expect(
      (await repository.loadProfile('member-id')).notificationsEnabled,
      isFalse,
    );
  });
  test('Missing profiles and zero-row updates are explicit failures', () async {
    missing = true;
    await expectLater(
      repository.loadProfile('member-id'),
      throwsA(isA<ProfileFailure>()),
    );
    await expectLater(
      repository.setNotifications(userId: 'member-id', enabled: false),
      throwsA(isA<ProfileFailure>()),
    );
  });
}
