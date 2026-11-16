import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:casa_en_juego/features/auth/models/auth_failure.dart';
import 'package:casa_en_juego/features/auth/repositories/account_photo_cache.dart';
import 'package:casa_en_juego/features/auth/repositories/account_photo_repository.dart';
import 'package:casa_en_juego/features/auth/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Directory directory;
  late AccountPhotoCache cache;
  final first = Uint8List.fromList([11, 22, 33]);
  final second = Uint8List.fromList([44, 55]);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('casa-en-juego-avatars');
    cache = AccountPhotoCache(directory: () async => directory);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'Cached images survive restart and remain isolated by account and URL',
    () async {
      const google = 'https://example.com/google.png';
      const github = 'https://example.com/github.png';
      await cache.write('first-account', first);
      await cache.write('first-account', second, providerUrl: google);
      await cache.write('second-account', second);

      final restored = AccountPhotoCache(directory: () async => directory);
      expect(await restored.read('first-account'), first);
      expect(await restored.read('second-account'), second);
      expect(await restored.read('third-account'), isNull);
      expect(await restored.read('first-account', providerUrl: google), second);
      expect(await restored.read('first-account', providerUrl: github), isNull);

      await restored.write('first-account', second);
      expect(await restored.read('first-account'), second);
      await restored.removeCustom('first-account');
      expect(await restored.read('first-account'), isNull);
      expect(await restored.read('second-account'), second);
      expect(await restored.read('first-account', providerUrl: google), second);
    },
  );

  test('Storage uses disk for a network error and clears it when the photo is gone', () async {
    var offline = false;
    var missing = false;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-public-key',
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          endsWith('/account-avatars/first-account/avatar'),
        );
        if (offline) throw http.ClientException('offline', request.url);
        if (missing) return http.Response('Not found', 404);
        return http.Response.bytes(first, 200);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAccountPhotoRepository(client, cache);
    expect(await repository.load('first-account'), first);
    offline = true;
    final restored = SupabaseAccountPhotoRepository(client, cache);
    expect(await restored.load('first-account'), first);
    offline = false;
    missing = true;
    expect(await restored.load('first-account'), isNull);
    expect(await cache.read('first-account'), isNull);
  });

  test(
    'A restored confirmed session can identify its avatar offline',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-public-key',
        httpClient: MockClient((request) async {
          throw http.ClientException('offline', request.url);
        }),
      );
      addTearDown(client.dispose);
      final expires = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'exp': expires})),
      );
      await client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'e30.$payload.signature',
          'refresh_token': 'test',
          'token_type': 'bearer',
          'user': {
            'id': 'first-account',
            'email': 'user@example.com',
            'email_confirmed_at': '2026-11-01T00:00:00Z',
            'created_at': '2026-11-01T00:00:00Z',
            'app_metadata': {
              'provider': 'email',
              'providers': ['email', 'google'],
            },
            'user_metadata': {'name': 'Ana', 'provider': 'google'},
          },
        }),
      );

      await expectLater(
        SupabaseAuthRepository(client).watchUser().first,
        throwsA(
          isA<OfflineProfileFailure>()
              .having((error) => error.userId, 'account', 'first-account')
              .having((error) => error.canEditPhoto, 'email origin', isTrue),
        ),
      );
    },
  );
}
