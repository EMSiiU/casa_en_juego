abstract final class SupabaseConfig {
  // La clave pública identifica el proyecto; la autorización depende de RLS.
  // Los valores pueden sustituirse mediante --dart-define al compilar.
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://omselvknclwasrypkxhp.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_uQmIgh7FI_uEzgryKOGGLQ_UGIwjsJT',
  );
}
