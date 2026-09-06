import '../../data/models/models.dart';

/// Serviço central de permissões do Conecta (§44–§49).
///
/// TODA decisão de permissão passa por aqui — nunca espalhar
/// `if (role == UserRole.developer)` pelas páginas.
///
/// Regras de segurança obrigatórias:
///  • Nenhum e-mail é comparado no código (proibido: `if (email == ...)`).
///  • O cargo é definido EXCLUSIVAMENTE no backend quando o Supabase for
///    conectado (Auth + tabela de roles + RLS + validação server-side).
///  • Esconder botão na interface é apenas UX — NÃO é segurança.
///  • O usuário NUNCA pode promover a própria conta (a tela de edição de
///    perfil não oferece escolha de cargo).
class PermissionService {
  const PermissionService._();

  static bool _isDeveloper(UserProfile? user) =>
      user != null && user.role == UserRole.developer;

  /// Marcar / trocar / remover a melhor resposta em Materiais (§35).
  /// Usuários comuns e o autor da pergunta NÃO podem.
  static bool canMarkAcceptedAnswer(UserProfile? user) => _isDeveloper(user);

  /// Criar comunicado escolar na aba Escola (§37).
  static bool canCreateSchoolAnnouncement(UserProfile? user) =>
      _isDeveloper(user);

  /// Editar comunicado escolar existente (§38).
  static bool canEditSchoolAnnouncement(UserProfile? user) =>
      _isDeveloper(user);

  /// Remover comunicado escolar (§38).
  static bool canDeleteSchoolAnnouncement(UserProfile? user) =>
      _isDeveloper(user);

  /// Acesso ao painel de ferramentas administrativas (futuro, §36).
  static bool canAccessDeveloperPanel(UserProfile? user) => _isDeveloper(user);

  /// Moderação geral de conteúdo (posts, respostas, comentários).
  static bool canModerateContent(UserProfile? user) => _isDeveloper(user);

  // -------------------------------------------------------------------------
  // Projetos, comentários e denúncias (rodada 6)
  // -------------------------------------------------------------------------

  /// Excluir um projeto inteiro: SOMENTE o autor principal
  /// (`project.authorId`). Ser colaborador NÃO concede essa permissão.
  static bool canDeleteProject(UserProfile? user, Project project) =>
      user != null && user.id == project.authorId;

  /// Excluir um comentário: SOMENTE o autor do comentário OU o autor
  /// principal do projeto onde ele foi feito. Colaboradores do projeto
  /// NÃO podem apagar comentários de terceiros.
  static bool canDeleteComment(
          UserProfile? user, ProjectComment comment, Project project) =>
      user != null &&
      (user.id == comment.authorId || user.id == project.authorId);

  /// Denunciar um projeto: qualquer usuário logado que NÃO participa
  /// dele (autor/colaboradores não denunciam o próprio projeto).
  static bool canReportProject(UserProfile? user, Project project) =>
      user != null && !project.involves(user.id);

  /// Analisar a fila de denúncias (dispensar / tomar ação) — somente
  /// Developers, a moderação oficial do Conecta.
  static bool canReviewProjectReport(UserProfile? user) => _isDeveloper(user);
}
