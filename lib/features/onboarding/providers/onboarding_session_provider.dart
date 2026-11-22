import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';

final onboardingSessionProvider =
    NotifierProvider<OnboardingSessionController, String?>(
      OnboardingSessionController.new,
    );

/// Recuerda la invitación al tutorial durante la sesión, sin persistencia local.
class OnboardingSessionController extends Notifier<String?> {
  String? _accountId;

  @override
  String? build() {
    final initial = ref.read(currentUserProvider).asData?.value;
    _accountId = initial?.id;
    ref.listen(currentUserProvider, (previous, next) {
      if (next.isLoading || next.hasError) return;
      final user = next.asData?.value;
      if (user == null) {
        _accountId = null;
        state = null;
      } else if (user.id != _accountId) {
        _accountId = user.id;
        state = user.isHouseholdMember ? null : user.id;
      } else if (user.isHouseholdMember) {
        state = null;
      }
    });
    return initial != null && !initial.isHouseholdMember ? initial.id : null;
  }

  void markShown(String accountId) {
    if (state == accountId) state = null;
  }
}
