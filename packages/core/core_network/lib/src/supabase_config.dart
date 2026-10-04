class SupabaseConfig {
  final String url;
  final String anonKey;
  const SupabaseConfig({required this.url, required this.anonKey});

  factory SupabaseConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Falta SUPABASE_URL o SUPABASE_ANON_KEY. '
        'Corre con --dart-define=SUPABASE_URL=http://127.0.0.1:54421 '
        '--dart-define=SUPABASE_ANON_KEY=<anon-key>',
      );
    }
    return const SupabaseConfig(url: url, anonKey: anonKey);
  }
}
