class SupabaseConfig {
  final String url;
  final String publishableKey;
  const SupabaseConfig({required this.url, required this.publishableKey});

  factory SupabaseConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'Falta SUPABASE_URL o SUPABASE_ANON_KEY. '
        'Corre con --dart-define=SUPABASE_URL=http://127.0.0.1:54421 '
        '--dart-define=SUPABASE_ANON_KEY=<publishable-key>',
      );
    }
    return const SupabaseConfig(url: url, publishableKey: publishableKey);
  }
}
