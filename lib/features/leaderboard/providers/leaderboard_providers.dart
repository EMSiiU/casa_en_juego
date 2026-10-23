import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/leaderboard_data.dart';
import '../models/leaderboard_failure.dart';
import '../repositories/leaderboard_repository.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (ref) => SupabaseLeaderboardRepository(ref.watch(supabaseClientProvider)),
);

final leaderboardProvider = FutureProvider.autoDispose<LeaderboardData>((
  ref,
) async {
  final user = ref.watch(currentUserProvider).asData?.value;
  if (user == null) {
    throw const LeaderboardFailure('Inicia sesión para ver el ranking.');
  }
  final repository = ref.watch(leaderboardRepositoryProvider);
  try {
    return await repository.loadLeaderboard();
  } catch (error) {
    if (kDebugMode) {
      // No se imprimen sesiones, claves ni registros de los miembros.
      debugPrint(
        'leaderboard.load failed: ${error is PostgrestException ? '${error.code}: ${error.message}' : error.runtimeType}',
      );
    }
    rethrow;
  }
}, retry: (retryCount, error) => null);
