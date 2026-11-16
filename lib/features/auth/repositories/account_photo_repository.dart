import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_photo_cache.dart';

abstract interface class AccountPhotoRepository {
  Future<Uint8List?> load(String userId);
  Future<void> save(String userId, Uint8List bytes, String contentType);
  Future<void> remove(String userId);
}

class SupabaseAccountPhotoRepository implements AccountPhotoRepository {
  SupabaseAccountPhotoRepository(SupabaseClient client, this._cache)
    : _bucket = client.storage.from('account-avatars');

  final StorageFileApi _bucket;
  final AccountPhotoCache _cache;
  Future<void> _pending = Future.value();

  Future<T> _ordered<T>(Future<T> Function() operation) {
    final next = _pending.then((_) => operation());
    // Una lectura anterior no debe volver a guardar la foto tras un cambio.
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  @override
  Future<Uint8List?> load(String userId) => _ordered(() async {
    try {
      final bytes = await _bucket
          .download(
            '$userId/avatar',
            cacheNonce: DateTime.now().microsecondsSinceEpoch.toString(),
          )
          .timeout(const Duration(seconds: 5));
      await _cache.write(userId, bytes);
      return bytes;
    } on StorageException catch (error) {
      if (error.statusCode == '404') {
        await _cache.removeCustom(userId);
        return null;
      }
      rethrow;
    } on http.ClientException {
      return _cache.read(userId);
    } on TimeoutException {
      return _cache.read(userId);
    }
  });

  @override
  Future<void> save(String userId, Uint8List bytes, String contentType) =>
      _ordered(() async {
        await _bucket.uploadBinary(
          '$userId/avatar',
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            cacheControl: '0',
            upsert: true,
          ),
          retryAttempts: 0,
        );
        await _cache.write(userId, bytes);
      });

  @override
  Future<void> remove(String userId) => _ordered(() async {
    await _bucket.remove(['$userId/avatar']);
    await _cache.removeCustom(userId);
  });
}
