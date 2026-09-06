import '../models/models.dart';

/// Lançada no cadastro quando o backend exige confirmação de e-mail:
/// a conta é criada, mas sem sessão até o usuário confirmar.
class EmailConfirmationRequiredException implements Exception {
  const EmailConfirmationRequiredException();

  @override
  String toString() => 'EmailConfirmationRequiredException';
}

/// Estatísticas agregadas do usuário para a dashboard.
class UserStats {
  const UserStats({
    required this.projectsPublished,
    required this.ratingsReceived,
    required this.likesReceived,
    required this.ratingAvg,
    required this.xpTotal,
    this.correctAnswers = 0,
  });

  final int projectsPublished;
  final int ratingsReceived;
  final int likesReceived;
  final double ratingAvg;
  final int xpTotal;

  /// Respostas em Materiais oficialmente selecionadas pela moderação.
  final int correctAnswers;
}

/// Rascunho para criação de projeto (fluxo "Novo Projeto").
class ProjectDraft {
  const ProjectDraft({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.type,
    this.tags = const [],
    this.media = const [],
    this.collaboratorIds = const [],
    this.textContent,
    this.cardTone,
  });

  final String title;
  final String subtitle;
  final String description;
  final ProjectCategory category;
  final ProjectType type;
  final List<String> tags;
  final List<ProjectMedia> media;
  final List<String> collaboratorIds;

  /// Conteúdo e cor do card (apenas type == ProjectType.texto).
  final String? textContent;
  final TextCardTone? cardTone;
}

/// Tabs do feed "Descobrir Projetos".
enum DiscoverTab { paraVoce, podio, estudantis, autorais, docentes, recentes }

abstract class AuthRepository {
  UserProfile? get currentUser;
  Stream<UserProfile?> watchCurrentUser();
  Future<UserProfile> signIn({required String email, required String password});
  Future<UserProfile> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  });
  Future<void> signOut();
}

/// Dados editáveis do perfil (§2). NUNCA inclui cargo/role — o usuário
/// não pode promover a própria conta (§46).
class ProfileUpdate {
  const ProfileUpdate({
    this.name,
    this.avatarUrl,
    this.clearAvatar = false,
    this.bio,
    this.instagram,
    this.xHandle,
    this.contactNumber,
    this.schoolId,
    this.clearSchool = false,
  });

  final String? name;
  final String? avatarUrl;
  final bool clearAvatar;
  final String? bio;
  final String? instagram;
  final String? xHandle;
  final String? contactNumber;
  final String? schoolId;
  final bool clearSchool;
}

abstract class ProfileRepository {
  Future<UserProfile?> getByUsername(String username);

  /// Busca direta por ID (avatar do autor de notificações, §18).
  Future<UserProfile?> getById(String userId);
  Future<UserStats> stats(String userId);
  Future<List<XpEvent>> xpEvents(String userId, {int limit = 10});
  Future<RankTier> rankOf(String userId);

  /// Posição do usuário dentro do próprio rank (1-based).
  Future<int> positionInRank(String userId);

  /// Projetos de um usuário.
  Future<List<Project>> projectsOf(String userId);

  /// Atualiza o perfil do usuário logado (§2). Alterações de nome/foto
  /// refletem em todo o app porque as telas referenciam o MESMO objeto
  /// de perfil — não há cópias independentes de nome/foto.
  Future<UserProfile> updateProfile(ProfileUpdate update);
}

/// Escolas cadastradas (§8) + comunicados escolares (§37–§40).
abstract class SchoolRepository {
  /// Lista escolas ativas; [query] filtra por nome/cidade/estado
  /// (seletor com busca do Editar Perfil — §9).
  Future<List<School>> listSchools({String query = ''});

  Future<School?> getById(String id);

  /// Comunicados de uma escola (aba Escola / filtro "Minha escola").
  Future<List<SchoolAnnouncement>> announcementsOf(String schoolId);

  Future<SchoolAnnouncement> createAnnouncement({
    required String schoolId,
    required String title,
    String? subtitle,
    required String content,
    required AnnouncementCategory category,
  });

  Future<void> updateAnnouncement(
    String id, {
    String? title,
    String? subtitle,
    String? content,
    AnnouncementCategory? category,
  });

  Future<void> deleteAnnouncement(String id);

  /// Estatísticas reais da escola, derivadas de profiles + projects +
  /// ratings (rodada 6): alunos únicos por schoolId, projetos publicados
  /// pelos autores da escola e média de TODAS as avaliações válidas
  /// (somatório ÷ quantidade — nunca média de médias).
  Future<SchoolStats> stats(String schoolId);
}

/// Resultado da pesquisa global (§27–§33), agrupado por categoria.
class GlobalSearchResults {
  const GlobalSearchResults({
    this.users = const [],
    this.projects = const [],
    this.materials = const [],
  });

  final List<UserProfile> users;
  final List<Project> projects;
  final List<MaterialPost> materials;

  bool get isEmpty => users.isEmpty && projects.isEmpty && materials.isEmpty;
  int get total => users.length + projects.length + materials.length;
}

abstract class SearchRepository {
  /// Busca parcial em usuários (nome/username), projetos (título/
  /// subtítulo/conteúdo) e materiais (título/conteúdo) — §30.
  Future<GlobalSearchResults> search(String query);
}

// ---------------------------------------------------------------------------
// Denúncias de projetos (rodada 6) — contrato único; mock hoje
// (LocalReportRepository), Supabase depois, sem trocar a UI.
// ---------------------------------------------------------------------------

abstract class ReportRepository {
  /// Envia uma denúncia para análise da moderação. NUNCA remove o
  /// projeto. O mesmo usuário não pode empilhar denúncias pendentes
  /// para o mesmo projeto — nesse caso retorna a denúncia já existente.
  Future<ProjectReport> reportProject(
    String projectId, {
    required ReportReason reason,
    String? description,
  });

  /// Denúncias pendentes enviadas pelo usuário logado (para a UI saber
  /// que "você já denunciou este projeto" sem expor nada ao autor).
  Future<List<ProjectReport>> myPendingReports();

  /// Fila de denúncias para a moderação (somente Developers — validado
  /// na camada de dados; no Supabase, por RLS). O painel administrativo
  /// completo é futuro, mas o acesso aos dados já fica pronto aqui.
  Future<List<ProjectReport>> pendingReports();

  /// Dispensar ou tomar ação em uma denúncia (somente Developers).
  Future<void> reviewReport(String reportId, ReportStatus result);
}

abstract class ProjectRepository {
  Future<List<Project>> list({
    DiscoverTab tab = DiscoverTab.paraVoce,
    ProjectCategory? category,
    String query = '',
    int page = 0,
    int pageSize = 12,
  });

  Future<Project?> getById(String id);
  Future<UserProfile?> authorOf(String authorId);
  Future<Project> create(ProjectDraft draft);

  /// Edição de projeto (autor/colaboradores): dados básicos e acréscimo
  /// de arquivos ao repositório. [media], quando informada, SUBSTITUI a
  /// lista completa de mídias do projeto.
  Future<void> updateProject(
    String projectId, {
    String? title,
    String? subtitle,
    String? description,
    String? textContent,
    List<ProjectMedia>? media,
  });

  /// Marca o projeto como 100% concluído (ou reabre, com false).
  Future<void> setCompleted(String projectId, bool completed);

  /// Exclui o projeto (SOMENTE o autor principal — validado também na
  /// camada de dados; no Supabase, por RLS). Remove junto todas as
  /// relações: mídias, colaboradores, curtidas, salvos, avaliações,
  /// comentários e denúncias ligadas a ele. Nada no app pode continuar
  /// apontando para um projeto inexistente.
  Future<void> deleteProject(String projectId);

  Future<void> toggleLike(String projectId);
  Future<void> toggleSave(String projectId);
  Future<void> rate(String projectId, int score, String? comment);
  Future<List<Rating>> ratings(String projectId);

  /// Comentários soltos do projeto (independentes de avaliação).
  Future<List<ProjectComment>> comments(String projectId);
  Future<ProjectComment> addComment(String projectId, String text);

  /// Exclui um comentário — autor do comentário ou autor principal do
  /// projeto (regra centralizada em PermissionService.canDeleteComment;
  /// no Supabase, RLS). O contador do projeto é atualizado pelo trigger
  /// / pela derivação da fonte única.
  Future<void> deleteComment(String commentId);

  Future<List<UserProfile>> searchUsers(String query);

  /// Último projeto editado pelo usuário (card "Continue seu projeto").
  Future<Project?> lastEditedProject(String userId);
}

abstract class RankingRepository {
  Future<List<LeaderboardEntry>> leaderboard({
    String scope = 'global', // global | escola
    RankTier? rankFilter,
  });
}

/// Conquistas do usuário (progresso + desbloqueio).
abstract class BadgeRepository {
  /// Todos os badges com progresso/estado para o usuário.
  /// A avaliação das condições é feita pela camada de dados
  /// (mock local ou RPC no Supabase) — nunca pela UI.
  Future<List<UserBadge>> badgesOf(String userId);
}

/// Postagens e respostas da aba Materiais.
abstract class MaterialRepository {
  Future<List<MaterialPost>> listPosts({
    String subject = 'Todos',
    MaterialPostKind? kind,
    String query = '',
  });

  Future<MaterialPost?> getPost(String id);
  Future<List<MaterialAnswer>> answersOf(String postId);

  Future<MaterialPost> createPost({
    required String title,
    required String content,
    required String subject,
    required MaterialPostKind kind,
  });

  Future<MaterialAnswer> answer(String postId, String content);

  /// Seleciona `answerId` como melhor resposta do post (apenas
  /// moderador/admin). Se outra resposta estava selecionada, ela perde
  /// o status. `null` remove a seleção atual.
  Future<void> selectBestAnswer(String postId, String? answerId);
}

/// Mensagens diretas e em grupo (§20–§26).
abstract class MessagingRepository {
  Future<List<Conversation>> conversations();

  /// Abre a conversa existente com o usuário ou cria uma nova.
  /// Nunca duplica a conversa do mesmo par de usuários.
  Future<Conversation> getOrCreateConversation(String otherUserId);

  Future<List<Message>> messages(String conversationId);
  Future<Message> sendMessage(String conversationId, String content);
  Future<void> markRead(String conversationId);

  // -- Grupos (§20–§26) ------------------------------------------------------

  /// Cria o grupo e ENVIA CONVITES aos usuários selecionados — selecionar
  /// alguém NÃO o coloca automaticamente dentro do grupo (§21).
  Future<Conversation> createGroup({
    required String name,
    String? imageUrl,
    required List<String> invitedUserIds,
  });

  /// Convites pendentes recebidos pelo usuário logado.
  Future<List<GroupInvite>> myPendingInvites();

  /// Resolve os dados de exibição de um convite (grupo + quem convidou).
  Future<({Conversation group, UserProfile inviter})> inviteContext(
      GroupInvite invite);

  /// Aceita o convite (somente o convidado). Retorna a conversa do grupo.
  Future<Conversation> acceptInvite(String inviteId);

  /// Ignora o convite (não entra no grupo, não notifica).
  Future<void> ignoreInvite(String inviteId);

  /// Papel do usuário logado dentro de um grupo.
  Future<GroupRole?> myRoleIn(String conversationId);
}

// ---------------------------------------------------------------------------
// Notificações (rodada 4, §16/§21) — contrato único; mock hoje, Supabase
// depois, sem mudar a UI.
// ---------------------------------------------------------------------------

abstract class NotificationRepository {
  /// Notificações do usuário, mais recentes primeiro.
  Future<List<AppNotification>> notificationsOf(String userId);

  /// Quantidade de não lidas (badge do sino).
  Future<int> unreadCount(String userId);

  /// Marcar como lida ao abrir/clicar (§19).
  Future<void> markRead(String notificationId);

  /// "Marcar todas como lidas" (§20).
  Future<void> markAllRead(String userId);
}

// ---------------------------------------------------------------------------
// Biblioteca (rodada 4, §37) — abstração clara: LocalSavedProjectsRepository
// agora, SupabaseSavedProjectsRepository futuramente, sem trocar a UI.
// ---------------------------------------------------------------------------

abstract class SavedProjectsRepository {
  /// Relações usuário ↔ projeto, mais recentes primeiro. Projetos removidos
  /// não são retornados como conteúdo — a UI resolve e ignora ausentes (§33).
  Future<List<SavedProject>> savedRelations(String userId);

  Future<bool> isSaved(String userId, String projectId);

  /// Alterna salvar/remover (§26–§27). Retorna o novo estado (true = salvo).
  /// Nunca duplica a relação userId + projectId (§32).
  Future<bool> toggle(String userId, String projectId);
}
