import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  );
  ref.onDispose(session.dispose);
  return session;
});

final pushDeviceStatusProvider = StreamProvider<PushDeviceStatus>((ref) async* {
  final session = ref.watch(notificationSessionProvider);
  yield session?.status ?? PushDeviceStatus.unavailable;
  if (session != null) yield* session.statuses;
});
