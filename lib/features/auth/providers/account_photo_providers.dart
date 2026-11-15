import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_provider.dart';
import '../repositories/account_photo_repository.dart';

final accountPhotoRepositoryProvider = Provider<AccountPhotoRepository>(
  (ref) => SupabaseAccountPhotoRepository(ref.watch(supabaseClientProvider)),
);

final accountPhotoProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>(
      (ref, userId) => ref.watch(accountPhotoRepositoryProvider).load(userId),
      retry: (count, error) => null,
    );
