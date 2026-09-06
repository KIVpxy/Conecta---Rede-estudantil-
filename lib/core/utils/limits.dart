/// Limites centralizados de conteúdo (SPEC §44).
///
/// Regras de negócio não ficam espalhadas pelas telas: qualquer
/// validação de tamanho máximo/mínimo referencia esta classe.
class AppLimits {
  AppLimits._();

  /// Tamanho máximo do corpo de um projeto do tipo Texto.
  static const int textProjectMaxLength = 20000;

  /// Tamanho máximo do conteúdo de uma postagem em Materiais.
  static const int materialPostMaxLength = 8000;

  /// Tamanho máximo de uma resposta em Materiais.
  static const int materialAnswerMaxLength = 4000;

  /// Tamanho máximo de uma mensagem (direta ou em grupo).
  static const int messageMaxLength = 2000;

  /// Tamanho máximo da bio do perfil (§4 — configurável aqui).
  static const int bioMaxLength = 300;

  /// Tamanho máximo do nome de exibição.
  static const int displayNameMaxLength = 50;

  /// Debounce da pesquisa global (§32): entre 250ms e 400ms.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  /// Máximo de resultados por categoria no preview da topbar (§31).
  static const int searchPreviewPerCategory = 5;
}
