import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static Future<void> initialize() {
    return Supabase.initialize(
      url: 'https://uxtxzhcoicqbgislrugi.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV4dHh6aGNvaWNxYmdpc2xydWdpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNDc5NTksImV4cCI6MjA5MTYyMzk1OX0.E1f6G2HubLbFVcTAlqOco6BKXJzWjpkcnEbvqmpt1W8',
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
