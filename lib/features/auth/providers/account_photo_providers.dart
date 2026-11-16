import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/supabase_provider.dart';
import '../repositories/account_photo_cache.dart';
import '../repositories/account_photo_repository.dart';

final accountPhotoCacheProvider = Provider<AccountPhotoCache>(
  (ref) => AccountPhotoCache(),
);

final accountPhotoRepositoryProvider = Provider<AccountPhotoRepository>(
  (ref) => SupabaseAccountPhotoRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(accountPhotoCacheProvider),
  ),
);

final accountPhotoProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>(
      (ref, userId) => ref.watch(accountPhotoRepositoryProvider).load(userId),
      retry: (count, error) => null,
    );

final cachedAccountPhotoProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>(
      (ref, userId) => ref.watch(accountPhotoCacheProvider).read(userId),
    );

final providerAvatarPhotoProvider = FutureProvider.autoDispose
    .family<Uint8List?, ({String userId, String url, bool localOnly})>((
      ref,
      key,
    ) async {
      final cache = ref.watch(accountPhotoCacheProvider);
      final cached = await cache.read(
        key.userId,
        providerUrl: key.url,
        maxAge: key.localOnly ? null : const Duration(days: 1),
      );
      if (cached != null || key.localOnly) return cached;
      try {
        final response = await http
            .get(Uri.parse(key.url))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 &&
            (response.headers['content-type']?.startsWith('image/') ?? false) &&
            response.bodyBytes.length <= 2 * 1024 * 1024) {
          await cache.write(
            key.userId,
            response.bodyBytes,
            providerUrl: key.url,
          );
          return response.bodyBytes;
        }
      } on http.ClientException {
        // El proveedor puede estar inaccesible incluso con sesión vigente.
      } on TimeoutException {
        // Deja disponible la última foto guardada si el proveedor tarda.
      }
      return cache.read(key.userId, providerUrl: key.url);
    });
