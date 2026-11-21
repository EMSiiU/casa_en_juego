import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../repositories/family_payment_repository.dart';

final familyPaymentSupportedProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

final familyPaymentRepositoryProvider = Provider<FamilyPaymentRepository>(
  (ref) => StripeFamilyPaymentRepository(ref.watch(supabaseClientProvider)),
);

final familyPaymentProvider =
    AsyncNotifierProvider.autoDispose<
      FamilyPaymentController,
      FamilyPaymentResult?
    >(FamilyPaymentController.new);

class FamilyPaymentController extends AsyncNotifier<FamilyPaymentResult?> {
  @override
  FamilyPaymentResult? build() {
    ref.watch(currentUserProvider.select((value) => value.asData?.value?.id));
    return null;
  }

  Future<void> checkout() async {
    final userId = ref.read(currentUserProvider).asData?.value?.id;
    if (state.isLoading ||
        userId == null ||
        !ref.read(familyPaymentSupportedProvider)) {
      return;
    }
    final pending = ref.keepAlive();
    state = const AsyncLoading();
    try {
      final result = await AsyncValue.guard(
        () => ref.read(familyPaymentRepositoryProvider).checkout(),
      );
      if (ref.mounted &&
          ref.read(currentUserProvider).asData?.value?.id == userId) {
        state = result;
      }
    } finally {
      pending.close();
    }
  }
}
