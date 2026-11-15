import 'package:supabase_flutter/supabase_flutter.dart';

String? providerAvatarUrl(User user) {
  final identities = user.identities ?? const <UserIdentity>[];
  final preferredProvider = user.appMetadata['provider'];
  for (final provider in {preferredProvider, 'google', 'github'}) {
    if (provider != 'google' && provider != 'github') continue;
    for (final identity in identities) {
      if (identity.provider != provider) continue;
      final data = identity.identityData;
      for (final value in [data?['picture'], data?['avatar_url']]) {
        if (value is! String) continue;
        final uri = Uri.tryParse(value);
        if (uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty) {
          return uri.toString();
        }
      }
    }
  }
  return null;
}
