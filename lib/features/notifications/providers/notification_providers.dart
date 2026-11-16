import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/supabase_provider.dart';
import '../models/push_notice.dart';
import '../repositories/notification_repository.dart';
import '../repositories/push_gateway.dart';
import '../services/notification_session.dart';

final pushRuntimeReadyProvider = Provider<bool>((ref) => false);
final notificationSessionProvider = Provider<NotificationSession?>((ref) {
  if (!ref.watch(pushRuntimeReadyProvider)) return null;
  final session = NotificationSession(
    gateway: FirebasePushGateway(),
    repository: SupabaseNotificationRepository(
      ref.watch(supabaseClientProvider),
    ),
    preferences: SharedPreferencesAsync(),
  );
  ref.onDispose(session.dispose);
  return session;
});

final generalNoticesProvider = AsyncNotifierProvider.autoDispose
    .family<GeneralNoticesController, bool, String>(
      GeneralNoticesController.new,
      retry: (_, _) => null,
    );

class GeneralNoticesController extends AsyncNotifier<bool> {
  GeneralNoticesController(this.userId);
  final String userId;

  @override
  Future<bool> build() async =>
      await ref
          .watch(notificationSessionProvider)
          ?.generalNoticesEnabled(userId) ??
      false;

  Future<void> setEnabled(bool enabled) async {
    final previous = state.asData;
    final session = ref.read(notificationSessionProvider);
    if (state.isLoading ||
        previous == null ||
        previous.value == enabled ||
        session == null) {
      return;
    }
    state = const AsyncLoading();
    try {
      await session.setGeneralNotices(userId, enabled);
      if (ref.mounted) state = AsyncData(enabled);
    } catch (_) {
      if (ref.mounted) state = previous;
      rethrow;
    }
  }
}

final pushDeviceStatusProvider = StreamProvider<PushDeviceStatus>((ref) async* {
  final session = ref.watch(notificationSessionProvider);
  yield session?.status ?? PushDeviceStatus.unavailable;
  if (session != null) yield* session.statuses;
});
