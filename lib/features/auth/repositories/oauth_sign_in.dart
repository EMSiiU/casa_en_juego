import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_provider.dart';
import '../models/auth_failure.dart';

const _mobileCallback = 'casaenjuego://auth/callback';

String oauthRedirectTo({required bool isWeb, required Uri appUri}) =>
    isWeb ? '${appUri.origin}/' : _mobileCallback;

final oauthSignInProvider = Provider<Future<void> Function(OAuthProvider)>((
  ref,
) {
  final auth = ref.watch(supabaseClientProvider).auth;
  return (provider) async {
    final opened = await auth.signInWithOAuth(
      provider,
      redirectTo: oauthRedirectTo(isWeb: kIsWeb, appUri: Uri.base),
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw const AuthFailure(
        'No pudimos abrir el navegador. Intenta de nuevo.',
      );
    }
  };
});
