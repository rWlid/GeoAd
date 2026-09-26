// must stay const: fromEnvironment only works at compile time
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isComplete => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
