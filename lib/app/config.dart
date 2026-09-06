/// Configuração via --dart-define.
///
/// Demo (padrão, sem backend):
///   flutter run
///
/// Com Supabase (URL e chave já ficam como padrão do projeto; para
/// trocar de projeto, sobrescreva via --dart-define):
///   flutter run --dart-define=USE_MOCK=false
class AppConfig {
  static const bool useMock =
      bool.fromEnvironment('USE_MOCK', defaultValue: true);
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://nayzpjzrqxgbwsxzfikj.supabase.co');
  static const String supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5heXpwanpycXhnYndzeHpmaWtqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxNDE1MzksImV4cCI6MjEwMzcxNzUzOX0.qReVIr18lgnybk9uv2IOLPkiDLdr7PxolshMnkwO-_k');
}
