class SupabaseClientConfig {
  const SupabaseClientConfig({
    required this.url,
    required this.anonKey,
  });

  final String url;
  final String anonKey;
}

// TODO: Initialize and expose Supabase.instance.client after adding supabase_flutter.
