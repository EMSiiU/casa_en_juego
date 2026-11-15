import 'package:casa_en_juego/features/auth/models/provider_avatar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User userWithIdentities(
  String primary,
  Map<String, Map<String, dynamic>> data,
) => User.fromJson({
  'id': 'test-user',
  'aud': 'authenticated',
  'created_at': '2026-11-14',
  'app_metadata': {'provider': primary},
  'user_metadata': {'avatar_url': 'https://example.com/unverified'},
  'identities': [
    for (final entry in data.entries)
      {
        'id': entry.key,
        'user_id': 'test-user',
        'provider': entry.key,
        'identity_data': entry.value,
      },
  ],
})!;

void main() {
  test('Provider avatar prefers the primary social identity and supports linked accounts', () {
    const google = 'https://lh3.googleusercontent.com/google-photo';
    const github = 'https://avatars.githubusercontent.com/u/1';
    final identities = {
      'google': {'picture': google},
      'github': {'avatar_url': github},
    };
    expect(providerAvatarUrl(userWithIdentities('github', identities)), github);
    expect(providerAvatarUrl(userWithIdentities('email', identities)), google);
  });

  test('Fallback ignores user metadata and unusable provider URLs', () {
    final user = userWithIdentities('google', {
      'google': {'picture': 'http://example.com/insecure'},
      'email': {'avatar_url': 'https://example.com/not-a-provider-avatar'},
    });
    expect(providerAvatarUrl(user), isNull);
  });
}
