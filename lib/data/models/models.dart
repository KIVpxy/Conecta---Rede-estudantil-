/// Modelos de dados do Conecta (SPEC §5).
library;

enum ProjectType { estudantil, autoral, docente, texto }

enum ProjectCategory {
  ciencias,
  matematica,
  tecnologia,
  historia,
  arte,
  literatura,
  meioAmbiente,
  engenharia,
  programacao,
  outros,
}

enum RankTier { bronze, ouro, esmeralda, diamante, sublime }

enum ProjectMediaKind { image, video, pdf, file, link, github }

/// Tom do card de um projeto do tipo Texto (cores em TextCardPalette).
enum TextCardTone { marrom, azul, vinho, amarelo }

/// Cargo do usuário na plataforma (§19, §34).
/// Rank é progressão/identidade visual; cargo é permissão.
/// Não existe cargo "Moderator" separado: o Developer acumula a
/// moderação oficial do Conecta. O cargo é definido EXCLUSIVAMENTE
/// no backend (quando o Supabase for conectado) — nunca por e-mail
/// fixo no código e nunca pelo próprio usuário (§44–§49).
enum UserRole { user, developer }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.user => 'Estudante',
        UserRole.developer => 'Developer',
      };
}

extension RankTierX on RankTier {
  String get label => switch (this) {
        RankTier.bronze => 'Bronze',
        RankTier.ouro => 'Ouro',
        RankTier.esmeralda => 'Esmeralda',
        RankTier.diamante => 'Diamante',
        RankTier.sublime => 'Sublime',
      };

  String get labelUpper => label.toUpperCase();
}

extension ProjectCategoryX on ProjectCategory {
  String get label => switch (this) {
        ProjectCategory.ciencias => 'Ciências',
        ProjectCategory.matematica => 'Matemática',
        ProjectCategory.tecnologia => 'Tecnologia',
        ProjectCategory.historia => 'História',
        ProjectCategory.arte => 'Arte',
        ProjectCategory.literatura => 'Literatura',
        ProjectCategory.meioAmbiente => 'Meio Ambiente',
        ProjectCategory.engenharia => 'Engenharia',
        ProjectCategory.programacao => 'Programação',
        ProjectCategory.outros => 'Outros',
      };
}

extension ProjectTypeX on ProjectType {
  String get label => switch (this) {
        ProjectType.estudantil => 'Projeto Estudantil',
        ProjectType.autoral => 'Projeto Autoral',
        ProjectType.docente => 'Projeto Docente',
        ProjectType.texto => 'Texto',
      };
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.xpTotal = 0,
    this.schoolId,
    this.bio,
    this.instagram,
    this.xHandle,
    this.contactNumber,
    this.role = UserRole.user,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final int xpTotal;

  /// Referência à escola (§8–§10): comparações e filtros usam o ID,
  /// nunca o nome textual. O nome é resolvido via SchoolRepository.
  final String? schoolId;

  /// Bio multilinha (§4) — quebras de linha preservadas na exibição.
  final String? bio;
  final String? instagram;
  final String? xHandle;
  final String? contactNumber;
  final UserRole role;
  final DateTime createdAt;

  bool get isDeveloper => role == UserRole.developer;

  UserProfile copyWith({
    int? xpTotal,
    String? name,
    String? avatarUrl,
    bool clearAvatar = false,
    String? bio,
    String? instagram,
    String? xHandle,
    String? contactNumber,
    String? schoolId,
    bool clearSchool = false,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        username: username,
        avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
        xpTotal: xpTotal ?? this.xpTotal,
        schoolId: clearSchool ? null : (schoolId ?? this.schoolId),
        bio: bio ?? this.bio,
        instagram: instagram ?? this.instagram,
        xHandle: xHandle ?? this.xHandle,
        contactNumber: contactNumber ?? this.contactNumber,
        role: role,
        createdAt: createdAt,
      );
}

/// Escola cadastrada (§8). Usuários referenciam por [School.id].
class School {
  const School({
    required this.id,
    required this.name,
    required this.city,
    required this.state,
    this.logoUrl,
    this.active = true,
  });

  final String id;
  final String name;
  final String city;
  final String state;
  final String? logoUrl;
  final bool active;

  String get location => '$city · $state';
}

class Project {
  const Project({
    required this.id,
    required this.authorId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.type,
    this.tags = const [],
    this.media = const [],
    this.collaborators = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.saveCount = 0,
    this.ratingCount = 0,
    this.ratingAvg = 0,
    this.likedByMe = false,
    this.savedByMe = false,
    this.textContent,
    this.cardTone,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String authorId;
  final String title;
  final String subtitle;
  final String description;
  final ProjectCategory category;
  final ProjectType type;
  final List<String> tags;
  final List<ProjectMedia> media;
  final List<UserProfile> collaborators;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final int ratingCount;
  final double ratingAvg; // 0..10
  final bool likedByMe;
  final bool savedByMe;

  /// Conteúdo textual completo (apenas type == ProjectType.texto).
  final String? textContent;

  /// Tom do card editorial (apenas type == ProjectType.texto).
  final TextCardTone? cardTone;
  final DateTime createdAt;

  /// Última edição de conteúdo/arquivos (null = nunca editado).
  final DateTime? updatedAt;

  /// Quando o projeto foi marcado como 100% concluído (null = em
  /// andamento). Alimenta o card "Continue seu projeto" do Status.
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  /// Momento da última atividade (edição ou criação).
  DateTime get lastActivity => updatedAt ?? createdAt;

  /// Quem participa do projeto (autor + colaboradores) não pode avaliá-lo.
  bool involves(String userId) =>
      authorId == userId || collaborators.any((c) => c.id == userId);

  Project copyWith({
    String? title,
    String? subtitle,
    String? description,
    String? textContent,
    int? likeCount,
    int? commentCount,
    int? saveCount,
    int? ratingCount,
    double? ratingAvg,
    bool? likedByMe,
    bool? savedByMe,
    List<ProjectMedia>? media,
    List<UserProfile>? collaborators,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompleted = false,
  }) =>
      Project(
        id: id,
        authorId: authorId,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        description: description ?? this.description,
        category: category,
        type: type,
        tags: tags,
        media: media ?? this.media,
        collaborators: collaborators ?? this.collaborators,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        saveCount: saveCount ?? this.saveCount,
        ratingCount: ratingCount ?? this.ratingCount,
        ratingAvg: ratingAvg ?? this.ratingAvg,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
        textContent: textContent ?? this.textContent,
        cardTone: cardTone,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        completedAt:
            clearCompleted ? null : (completedAt ?? this.completedAt),
      );
}

class ProjectMedia {
  const ProjectMedia({
    required this.id,
    required this.url,
    required this.kind,
    this.label,
  });

  final String id;
  final String url;
  final ProjectMediaKind kind;
  final String? label;
}

class Rating {
  const Rating({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.score, // 1..10
    this.comment,
    required this.createdAt,
    this.author,
  });

  final String id;
  final String projectId;
  final String userId;
  final int score;
  final String? comment;
  final DateTime createdAt;
  final UserProfile? author; // preenchido nas consultas
}

/// Comentário solto em um projeto — independente de avaliação.
/// Diferente do comentário opcional de [Rating], não carrega nota.
class ProjectComment {
  const ProjectComment({
    required this.id,
    required this.projectId,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.author,
  });

  final String id;
  final String projectId;
  final String authorId;
  final String text;
  final DateTime createdAt;
  final UserProfile? author; // preenchido nas consultas
}

// ---------------------------------------------------------------------------
// Denúncias de projetos (moderação)
// ---------------------------------------------------------------------------

/// Motivo de uma denúncia de projeto. `outro` permite descrição curta.
enum ReportReason {
  conteudoInadequado,
  assedioOuOfensa,
  spam,
  conteudoEnganoso,
  violacaoDeDireitos,
  conteudoImproprio,
  outro,
}

extension ReportReasonX on ReportReason {
  String get label => switch (this) {
        ReportReason.conteudoInadequado => 'Conteúdo inadequado',
        ReportReason.assedioOuOfensa => 'Assédio ou ofensa',
        ReportReason.spam => 'Spam',
        ReportReason.conteudoEnganoso => 'Conteúdo enganoso',
        ReportReason.violacaoDeDireitos => 'Violação de direitos',
        ReportReason.conteudoImproprio => 'Conteúdo impróprio',
        ReportReason.outro => 'Outro',
      };

  /// Valor persistido no banco (snake_case estável).
  String get storageKey => switch (this) {
        ReportReason.conteudoInadequado => 'conteudo_inadequado',
        ReportReason.assedioOuOfensa => 'assedio_ou_ofensa',
        ReportReason.spam => 'spam',
        ReportReason.conteudoEnganoso => 'conteudo_enganoso',
        ReportReason.violacaoDeDireitos => 'violacao_de_direitos',
        ReportReason.conteudoImproprio => 'conteudo_improprio',
        ReportReason.outro => 'outro',
      };

  static ReportReason fromStorageKey(String key) => switch (key) {
        'conteudo_inadequado' => ReportReason.conteudoInadequado,
        'assedio_ou_ofensa' => ReportReason.assedioOuOfensa,
        'spam' => ReportReason.spam,
        'conteudo_enganoso' => ReportReason.conteudoEnganoso,
        'violacao_de_direitos' => ReportReason.violacaoDeDireitos,
        'conteudo_improprio' => ReportReason.conteudoImproprio,
        _ => ReportReason.outro,
      };
}

/// Estado de uma denúncia na fila da moderação (Developers).
enum ReportStatus { pending, reviewed, dismissed, actionTaken }

extension ReportStatusX on ReportStatus {
  String get label => switch (this) {
        ReportStatus.pending => 'Pendente',
        ReportStatus.reviewed => 'Analisada',
        ReportStatus.dismissed => 'Dispensada',
        ReportStatus.actionTaken => 'Ação tomada',
      };

  String get storageKey => switch (this) {
        ReportStatus.pending => 'pending',
        ReportStatus.reviewed => 'reviewed',
        ReportStatus.dismissed => 'dismissed',
        ReportStatus.actionTaken => 'action_taken',
      };

  static ReportStatus fromStorageKey(String key) => switch (key) {
        'reviewed' => ReportStatus.reviewed,
        'dismissed' => ReportStatus.dismissed,
        'action_taken' => ReportStatus.actionTaken,
        _ => ReportStatus.pending,
      };
}

/// Denúncia de um projeto, enviada à moderação (Developers).
/// Reportar NUNCA remove o projeto automaticamente — apenas enfileira
/// para análise. O autor do projeto não tem acesso à identidade de
/// [reporterUserId].
class ProjectReport {
  const ProjectReport({
    required this.id,
    required this.projectId,
    required this.reporterUserId,
    required this.reason,
    this.description,
    this.status = ReportStatus.pending,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  final String id;
  final String projectId;
  final String reporterUserId;
  final ReportReason reason;

  /// Descrição curta — obrigatória quando [reason] é `outro`.
  final String? description;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
}

/// Estatísticas agregadas de uma escola, sempre DERIVADAS dos dados
/// reais (profiles.schoolId + projects + ratings) — nunca hardcoded.
class SchoolStats {
  const SchoolStats({
    required this.studentCount,
    required this.projectCount,
    required this.ratingAvg,
    required this.ratingCount,
  });

  /// Usuários únicos com profile.schoolId == escola (cada aluno conta 1x).
  final int studentCount;

  /// Projetos publicados cujo AUTOR principal pertence à escola
  /// (colaboradores de outras escolas não duplicam a contagem).
  final int projectCount;

  /// Média de TODAS as avaliações válidas recebidas pelos projetos da
  /// escola (somatório ÷ quantidade) — 0 quando não há avaliações.
  final double ratingAvg;
  final int ratingCount;
}

class XpEvent {
  const XpEvent({
    required this.id,
    required this.userId,
    required this.amount,
    required this.reason,
    this.projectId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final int amount;
  final String reason;
  final String? projectId;
  final DateTime createdAt;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.position,
    required this.user,
    required this.rank,
    required this.projectCount,
    required this.ratingAvg,
    required this.xpTotal,
    this.isCurrentUser = false,
  });

  final int position;
  final UserProfile user;
  final RankTier rank;
  final int projectCount;
  final double ratingAvg;
  final int xpTotal;
  final bool isCurrentUser;
}

// ---------------------------------------------------------------------------
// Materiais (postagens, respostas e melhor resposta da moderação)
// ---------------------------------------------------------------------------

/// Tipo da postagem em Materiais: compartilhamento de conteúdo,
/// pergunta/dúvida ou pedido de material.
enum MaterialPostKind { compartilhamento, pergunta, pedido }

extension MaterialPostKindX on MaterialPostKind {
  String get label => switch (this) {
        MaterialPostKind.compartilhamento => 'Material',
        MaterialPostKind.pergunta => 'Pergunta',
        MaterialPostKind.pedido => 'Pedido',
      };
}

class MaterialPost {
  const MaterialPost({
    required this.id,
    required this.authorId,
    required this.title,
    required this.content,
    required this.subject,
    required this.kind,
    this.acceptedAnswerId,
    this.answerCount = 0,
    this.author,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String title;
  final String content;
  final String subject;
  final MaterialPostKind kind;

  /// Resposta oficialmente selecionada pela moderação (máx. 1 por post).
  final String? acceptedAnswerId;
  final int answerCount;
  final UserProfile? author;
  final DateTime createdAt;

  bool get hasAcceptedAnswer => acceptedAnswerId != null;

  MaterialPost copyWith({
    String? acceptedAnswerId,
    int? answerCount,
    bool clearAccepted = false,
  }) =>
      MaterialPost(
        id: id,
        authorId: authorId,
        title: title,
        content: content,
        subject: subject,
        kind: kind,
        acceptedAnswerId:
            clearAccepted ? null : (acceptedAnswerId ?? this.acceptedAnswerId),
        answerCount: answerCount ?? this.answerCount,
        author: author,
        createdAt: createdAt,
      );
}

class MaterialAnswer {
  const MaterialAnswer({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    this.isAccepted = false,
    this.markedBy,
    this.markedAt,
    this.author,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String content;

  /// Verdadeiro apenas quando selecionada por moderador/admin.
  final bool isAccepted;

  /// Quem (moderação) selecionou e quando.
  final String? markedBy;
  final DateTime? markedAt;
  final UserProfile? author;
  final DateTime createdAt;

  MaterialAnswer copyWith({
    bool? isAccepted,
    String? markedBy,
    DateTime? markedAt,
    bool clearMark = false,
  }) =>
      MaterialAnswer(
        id: id,
        postId: postId,
        authorId: authorId,
        content: content,
        isAccepted: clearMark ? false : (isAccepted ?? this.isAccepted),
        markedBy: clearMark ? null : (markedBy ?? this.markedBy),
        markedAt: clearMark ? null : (markedAt ?? this.markedAt),
        author: author,
        createdAt: createdAt,
      );
}

// ---------------------------------------------------------------------------
// Badges / conquistas
// ---------------------------------------------------------------------------

enum BadgeId {
  autor,
  menteBrilhante1,
  menteBrilhante2,
  menteBrilhante3,
  thinker1,
  thinker2,
  thinker3,
  alunoAplicado1,
  alunoAplicado2,
  mastermind,
  euTenhoEVoce,
}

/// Definição estática de um badge (condição centralizada aqui).
class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.target,
  });

  final BadgeId id;
  final String name;
  final String description;

  /// Meta numérica (1 para badges de condição única).
  final int target;
}

/// Estado de um badge para um usuário específico.
class UserBadge {
  const UserBadge({
    required this.definition,
    required this.progress,
    this.unlockedAt,
  });

  final BadgeDefinition definition;

  /// Progresso atual em direção à meta (clamp em target na exibição).
  final int progress;
  final DateTime? unlockedAt;

  bool get unlocked => unlockedAt != null;
}

// ---------------------------------------------------------------------------
// Mensagens — conversas diretas e grupos (§20–§26)
// O sistema de mensagens atual foi ADAPTADO para grupos (não recriado).
// ---------------------------------------------------------------------------

enum ConversationType { direct, group }

/// Papel do membro dentro de um grupo (§23).
enum GroupRole { owner, admin, member }

class Conversation {
  const Conversation({
    required this.id,
    required this.participants,
    this.type = ConversationType.direct,
    this.name,
    this.imageUrl,
    this.createdBy,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final String id;

  final ConversationType type;

  /// Nome do grupo (apenas quando [type] == group).
  final String? name;

  /// Imagem opcional do grupo.
  final String? imageUrl;

  /// Quem criou o grupo (vira owner).
  final String? createdBy;

  /// Conversa direta: sempre 2. Grupo: membros atuais do grupo.
  final List<UserProfile> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  bool get isGroup => type == ConversationType.group;

  UserProfile other(String myId) =>
      participants.firstWhere((u) => u.id != myId, orElse: () => participants.first);
}

/// Membro de um grupo (§23).
class GroupMember {
  const GroupMember({
    required this.conversationId,
    required this.userId,
    this.role = GroupRole.member,
    required this.joinedAt,
  });

  final String conversationId;
  final String userId;
  final GroupRole role;
  final DateTime joinedAt;
}

enum InviteStatus { pending, accepted, ignored, expired, revoked }

/// Convite de grupo (§23). Selecionar alguém na criação do grupo NÃO o
/// coloca dentro do grupo: um convite é enviado e só o convidado pode
/// aceitar (ou ignorar).
class GroupInvite {
  const GroupInvite({
    required this.id,
    required this.groupId,
    required this.inviterId,
    required this.invitedUserId,
    required this.token,
    this.status = InviteStatus.pending,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String groupId;
  final String inviterId;
  final String invitedUserId;
  final String token;
  final InviteStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isPending => status == InviteStatus.pending;
}

// ---------------------------------------------------------------------------
// Comunicados escolares (§37–§40) — publicados por Developers na aba Escola.
// ---------------------------------------------------------------------------

enum AnnouncementCategory { aviso, evento, oportunidade, prova, olimpiada, geral }

extension AnnouncementCategoryX on AnnouncementCategory {
  String get label => switch (this) {
        AnnouncementCategory.aviso => 'Aviso',
        AnnouncementCategory.evento => 'Evento',
        AnnouncementCategory.oportunidade => 'Oportunidade',
        AnnouncementCategory.prova => 'Prova',
        AnnouncementCategory.olimpiada => 'Olimpíada',
        AnnouncementCategory.geral => 'Geral',
      };
}

class SchoolAnnouncement {
  const SchoolAnnouncement({
    required this.id,
    required this.schoolId,
    required this.authorId,
    required this.title,
    this.subtitle,
    required this.content,
    this.category = AnnouncementCategory.geral,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// Escola dona do comunicado. Integra o filtro "Minha escola" por ID.
  /// (Preparado para comunicados globais futuros, sem escola.)
  final String schoolId;
  final String authorId;
  final String title;
  final String? subtitle;
  final String content;
  final AnnouncementCategory category;
  final DateTime createdAt;
  final DateTime? updatedAt;
}

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.read = false,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool read;
  final DateTime createdAt;
}

// ---------------------------------------------------------------------------
// Notificações (rodada 4, §11–§21) — sino da topbar com contador de não lidas.
// Preparado para Supabase (tabela `notifications`); hoje servido pelo mock.
// ---------------------------------------------------------------------------

enum NotificationType {
  message,
  groupMessage,
  projectRating,
  groupInvite,
  system,
  schoolAnnouncement,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.type,
    this.actorUserId,
    this.referenceId,
    required this.title,
    required this.message,
    this.count = 1,
    required this.createdAt,
    this.readAt,
  });

  final String id;

  /// Dono da notificação — cada usuário só vê as próprias.
  final String recipientUserId;
  final NotificationType type;

  /// Quem disparou a ação (quem enviou a mensagem, quem avaliou…).
  final String? actorUserId;

  /// Destino ao clicar: conversationId (message/groupMessage), projectId
  /// (projectRating), inviteId (groupInvite), schoolId (schoolAnnouncement).
  final String? referenceId;
  final String title;
  final String message;

  /// Agregação de mensagens de grupo (§13): "5 novas mensagens em …"
  /// em vez de uma notificação por mensagem.
  final int count;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  AppNotification copyWith({
    String? message,
    int? count,
    DateTime? createdAt,
    DateTime? readAt,
  }) =>
      AppNotification(
        id: id,
        recipientUserId: recipientUserId,
        type: type,
        actorUserId: actorUserId,
        referenceId: referenceId,
        title: title,
        message: message ?? this.message,
        count: count ?? this.count,
        createdAt: createdAt ?? this.createdAt,
        readAt: readAt ?? this.readAt,
      );
}

// ---------------------------------------------------------------------------
// Biblioteca de projetos salvos (rodada 4, §25–§37).
// A Biblioteca guarda APENAS a relação usuário ↔ projeto (§32) — nunca uma
// cópia do conteúdo. Se o projeto for removido, a relação deixa de resolver
// e o item some da Biblioteca (§33).
// ---------------------------------------------------------------------------

class SavedProject {
  const SavedProject({
    required this.userId,
    required this.projectId,
    required this.savedAt,
  });

  final String userId;
  final String projectId;
  final DateTime savedAt;

  /// Par userId + projectId é único (§32) — sem entradas duplicadas.
  bool matches(String userId, String projectId) =>
      this.userId == userId && this.projectId == projectId;
}
