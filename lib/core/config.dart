import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase settings. Prefer --dart-define; runtime fallbacks work after hot restart.
class AppConfig {
  static const _defaultUrl = 'https://uvwzdbpisgxvasfkchbu.supabase.co';
  static const _defaultAnonKey = 'sb_publishable_CwdlJmaAudGKhp-6ZcATBg_absL391D';

  static const _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Resolved at runtime so an old build without dart-define still gets a host.
  static String get supabaseUrl => _envUrl.isNotEmpty ? _envUrl : _defaultUrl;

  static String get supabaseAnonKey => _envAnonKey.isNotEmpty ? _envAnonKey : _defaultAnonKey;

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

SupabaseClient get sb => Supabase.instance.client;

String friendlyError(Object e) {
  if (e is AuthException) return e.message;
  return e.toString().replaceAll('Exception:', '').trim();
}
