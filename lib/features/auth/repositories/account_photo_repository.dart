import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AccountPhotoRepository {
  Future<Uint8List?> load(String userId);
  Future<void> save(String userId, Uint8List bytes, String contentType);
  Future<void> remove(String userId);
}

class SupabaseAccountPhotoRepository implements AccountPhotoRepository {
  SupabaseAccountPhotoRepository(SupabaseClient client)
    : _bucket = client.storage.from('account-avatars');

  final StorageFileApi _bucket;

  @override
  Future<Uint8List?> load(String userId) async {
    try {
      return await _bucket.download(
        '$userId/avatar',
        cacheNonce: DateTime.now().microsecondsSinceEpoch.toString(),
      );
    } on StorageException catch (error) {
      if (error.statusCode == '404') return null;
      rethrow;
    }
  }

  @override
  Future<void> save(String userId, Uint8List bytes, String contentType) async {
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
  }

  @override
  Future<void> remove(String userId) async {
    await _bucket.remove(['$userId/avatar']);
  }
}
