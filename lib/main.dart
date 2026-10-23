import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/presentation/notification_host.dart';
import 'features/notifications/providers/notification_providers.dart';
import 'features/notifications/repositories/push_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  final pushReady = await initializePushNotifications();
  runApp(
    ProviderScope(
      overrides: [pushRuntimeReadyProvider.overrideWithValue(pushReady)],
      child: const CasaEnJuegoApp(),
    ),
  );
}

class CasaEnJuegoApp extends ConsumerWidget {
  const CasaEnJuegoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationHost(
      child: MaterialApp.router(
        title: 'Casa en Juego',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: ref.watch(appRouterProvider),
      ),
    );
  }
}
