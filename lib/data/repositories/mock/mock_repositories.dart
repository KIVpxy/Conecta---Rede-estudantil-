import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/services/badge_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/utils/level_math.dart';
import '../../models/models.dart';
import '../repositories.dart';
import 'mock_database.dart';

/// Repositórios em memória (modo demo). Estado mutável e reativo
/// via invalidação dos providers na camada de UI.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._db);

  final MockDatabase _db;
  final _controller = StreamController<UserProfile?>.broadcast();
  UserProfile? _current;

  @override
  UserProfile? get currentUser => _current;

  @override
  Stream<UserProfile?> watchCurrentUser() {
    Future.microtask(() => _controller.add(_current));
    return _controller.stream;
  }

  @override
  Future<UserProfile> signIn(
      {required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _current = _db.currentUser; // demo: entra como Kevin
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<UserProfile> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final user = UserProfile(
      id: 'u-${const Uuid().v4()}',
      name: name,
      username: username,
      xpTotal: 0,
      createdAt: DateTime.now(),
    );
    _db.users.add(user);
    _current = user;
    _controller.add(_current);
    return user;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }
}

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(this._db);

  final MockDatabase _db;

  List<UserProfile> get _sorted =>
      [..._db.users]..sort((a, b) => b.xpTotal.compareTo(a.xpTotal));

  RankTier _rankOf(String userId) {
    final xp = _db.users
        .firstWhere((u) => u.id == userId,
            orElse: () => _db.users.first)
        .xpTotal;
    return LevelMath.rankForXp(xp);
  }

  @override
  Future<UserProfile?> getById(String userId) async {
    for (final u in _db.users) {
      if (u.id == userId) return u;
    }
    return null;
  }

  @override
  Future<UserProfile?> getByUsername(String username) async {
    for (final u in _db.users) {
      if (u.username == username) return u;
    }
    return null;
  }

  @override
  Future<UserStats> stats(String userId) async {
    final mine = _db.projects.where((p) => p.authorId == userId).toList();
    final ratingsReceived =
        mine.fold<int>(0, (sum, p) => sum + p.ratingCount);
    final likes = mine.fold<int>(0, (sum, p) => sum + p.likeCount);
    final avg = mine.isEmpty
        ? 0.0
        : mine.fold<double>(0, (sum, p) => sum + p.ratingAvg) / mine.length;
    // Respostas corretas: somente as marcadas pela moderação (§28).
    final correctAnswers = _db.materialAnswers
        .where((a) => a.authorId == userId && a.isAccepted)
        .length;
    return UserStats(
      projectsPublished: mine.length,
      ratingsReceived: ratingsReceived,
      likesReceived: likes,
      ratingAvg: avg,
      xpTotal: _db.users.firstWhere((u) => u.id == userId).xpTotal,
      correctAnswers: correctAnswers,
    );
  }

  @override
  Future<List<XpEvent>> xpEvents(String userId, {int limit = 10}) async {
    final events = _db.xpEvents.where((e) => e.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return events.take(limit).toList();
  }

  @override
  Future<RankTier> rankOf(String userId) async => _rankOf(userId);

  @override
  Future<int> positionInRank(String userId) async {
    final tier = _rankOf(userId);
    final sorted = _sorted;
    var position = 0;
    for (final u in sorted) {
      if (_rankOf(u.id) == tier) {
        position++;
        if (u.id == userId) return position;
      }
    }
    return position;
  }

  @override
  Future<List<Project>> projectsOf(String userId) async {
    final mine =
        _db.projects.where((p) => p.authorId == userId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mine;
  }

  /// Atualiza o perfil na fonte ÚNICA de dados (§2). Todas as telas
  /// referenciam os mesmos objetos de `_db.users` (nome/foto nunca são
  /// copiados para lugares independentes), então a mudança reflete em
  /// todo o app. NUNCA permite alterar `role` (§46).
  @override
  Future<UserProfile> updateProfile(ProfileUpdate update) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final me = _db.currentUser;
    final i = _db.users.indexWhere((u) => u.id == me.id);
    if (i < 0) return me;
    final updated = _db.users[i].copyWith(
      name: update.name,
      avatarUrl: update.avatarUrl,
      clearAvatar: update.clearAvatar,
      bio: update.bio,
      instagram: update.instagram,
      xHandle: update.xHandle,
      contactNumber: update.contactNumber,
      schoolId: update.schoolId,
      clearSchool: update.clearSchool,
    );
    _db.users[i] = updated;
    return updated;
  }
}

class MockProjectRepository implements ProjectRepository {
  MockProjectRepository(this._db);

  final MockDatabase _db;

  /// Colaboradores são referências aos usuários (§2): resolve sempre da
  /// fonte única para que nome/foto editados reflitam nos projetos.
  /// O estado "salvo" (§26) também é derivado da relação userId ↔
  /// projectId — nunca de um flag solto no projeto. As contagens de
  /// saves e comentários são derivadas das listas reais, para que o
  /// número exibido seja sempre consistente com o conteúdo.
  Project _resolveCollaborators(Project p) {
    final saved = _db.savedProjects
        .any((s) => s.matches(MockDatabase.currentUserId, p.id));
    final saveCount =
        _db.savedProjects.where((s) => s.projectId == p.id).length;
    final commentCount =
        _db.comments.where((c) => c.projectId == p.id).length;
    var resolved = p.copyWith(
      savedByMe: saved,
      saveCount: saveCount,
      commentCount: commentCount,
    );
    if (resolved.collaborators.isEmpty) return resolved;
    return resolved.copyWith(collaborators: [
      for (final c in resolved.collaborators)
        _db.users.firstWhere((u) => u.id == c.id, orElse: () => c),
    ]);
  }

  @override
  Future<List<Project>> list({
    DiscoverTab tab = DiscoverTab.paraVoce,
    ProjectCategory? category,
    String query = '',
    int page = 0,
    int pageSize = 12,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    var result = [..._db.projects];

    // Filtro por tab.
    result = switch (tab) {
      DiscoverTab.estudantis => result
          .where((p) => p.type == ProjectType.estudantil)
          .toList(),
      DiscoverTab.autorais =>
        result.where((p) => p.type == ProjectType.autoral).toList(),
      DiscoverTab.docentes =>
        result.where((p) => p.type == ProjectType.docente).toList(),
      _ => result,
    };

    // Ordenação por tab.
    result.sort((a, b) => switch (tab) {
          DiscoverTab.podio => (b.ratingAvg * b.ratingCount)
              .compareTo(a.ratingAvg * a.ratingCount),
          _ => b.createdAt.compareTo(a.createdAt),
        });

    if (category != null) {
      result = result.where((p) => p.category == category).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              p.subtitle.toLowerCase().contains(q) ||
              p.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }

    final start = page * pageSize;
    if (start >= result.length) return [];
    return result
        .sublist(start,
            start + pageSize > result.length ? result.length : start + pageSize)
        .map(_resolveCollaborators)
        .toList();
  }

  @override
  Future<Project?> getById(String id) async {
    for (final p in _db.projects) {
      if (p.id == id) return _resolveCollaborators(p);
    }
    return null;
  }

  @override
  Future<UserProfile?> authorOf(String authorId) async {
    for (final u in _db.users) {
      if (u.id == authorId) return u;
    }
    return null;
  }

  @override
  Future<Project> create(ProjectDraft draft) async {
    final project = Project(
      id: 'p-${const Uuid().v4()}',
      authorId: _db.currentUser.id,
      title: draft.title,
      subtitle: draft.subtitle,
      description: draft.description,
      category: draft.category,
      type: draft.type,
      tags: draft.tags,
      media: draft.media,
      collaborators: [
        for (final id in draft.collaboratorIds)
          _db.users.firstWhere((u) => u.id == id),
      ],
      textContent: draft.textContent,
      cardTone: draft.cardTone,
      createdAt: DateTime.now(),
    );
    _db.projects.insert(0, project);
    BadgeSync.run(_db, project.authorId); // ex.: AUTOR
    return project;
  }

  void _replace(Project updated) {
    final i = _db.projects.indexWhere((p) => p.id == updated.id);
    if (i >= 0) _db.projects[i] = updated;
  }

  @override
  Future<void> toggleLike(String projectId) async {
    final p = await getById(projectId);
    if (p == null) return;
    _replace(p.copyWith(
      likedByMe: !p.likedByMe,
      likeCount: p.likedByMe ? p.likeCount - 1 : p.likeCount + 1,
    ));
  }

  @override
  Future<void> toggleSave(String projectId) async {
    final p = await getById(projectId);
    if (p == null) return;
    // Fonte de verdade é a relação userId ↔ projectId (§32); o flag
    // savedByMe do card apenas reflete essa relação.
    final saved = _db.toggleSaved(MockDatabase.currentUserId, projectId);
    _replace(p.copyWith(savedByMe: saved));
  }

  @override
  Future<void> updateProject(
    String projectId, {
    String? title,
    String? subtitle,
    String? description,
    String? textContent,
    List<ProjectMedia>? media,
  }) async {
    final p = await getById(projectId);
    if (p == null) return;

    // Só quem participa do projeto (autor ou colaborador) pode editar.
    final me = _db.currentUser;
    if (!p.involves(me.id)) return;

    _replace(p.copyWith(
      title: _nonEmpty(title) ?? p.title,
      subtitle: subtitle?.trim(),
      description: description?.trim(),
      textContent: textContent,
      media: media,
      updatedAt: DateTime.now(),
    ));
  }

  /// Título nunca fica vazio: retorna null se [value] for nulo ou vazio.
  static String? _nonEmpty(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Future<void> setCompleted(String projectId, bool completed) async {
    final p = await getById(projectId);
    if (p == null) return;

    final me = _db.currentUser;
    if (!p.involves(me.id)) return;

    _replace(p.copyWith(
      completedAt: completed ? DateTime.now() : null,
      clearCompleted: !completed,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Future<void> deleteProject(String projectId) async {
    final p = await getById(projectId);
    if (p == null) return;

    // Só o autor principal exclui — validado aqui também, não só na UI
    // (colaborador NÃO pode excluir o projeto inteiro).
    if (!PermissionService.canDeleteProject(_db.currentUser, p)) return;

    // Remove o projeto e TODAS as relações que apontam para ele —
    // nada pode continuar referenciando um projeto inexistente
    // (feed, perfil, Biblioteca, pesquisa e estatísticas derivam tudo
    // destas mesmas listas, então atualizam sozinhos).
    _db.projects.removeWhere((x) => x.id == projectId);
    _db.ratings.removeWhere((r) => r.projectId == projectId);
    _db.comments.removeWhere((c) => c.projectId == projectId);
    _db.savedProjects.removeWhere((s) => s.projectId == projectId);
    // Notificações ligadas ao projeto (referenceId = projectId para
    // notificações de avaliação) — nenhuma pode apontar para um
    // projeto inexistente.
    _db.notifications.removeWhere((n) => n.referenceId == projectId);
    _db.reports.removeWhere((r) => r.projectId == projectId);
    // xpEvents são histórico de XP já concedido — mantidos de propósito.
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final i = _db.comments.indexWhere((c) => c.id == commentId);
    if (i < 0) return;
    final comment = _db.comments[i];
    final project = await getById(comment.projectId);
    if (project == null) return;
    if (!PermissionService.canDeleteComment(
        _db.currentUser, comment, project)) {
      return;
    }
    _db.comments.removeAt(i);
    // O contador de comentários é derivado da lista (_resolveCollaborators)
    // — atualiza sozinho, sem contador paralelo para dessincronizar.
  }

  @override
  Future<List<ProjectComment>> comments(String projectId) async {
    final list =
        _db.comments.where((c) => c.projectId == projectId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final c in list)
        ProjectComment(
          id: c.id,
          projectId: c.projectId,
          authorId: c.authorId,
          text: c.text,
          createdAt: c.createdAt,
          author:
              _db.users.firstWhere((u) => u.id == c.authorId),
        ),
    ];
  }

  @override
  Future<ProjectComment> addComment(String projectId, String text) async {
    final me = _db.currentUser;
    final comment = ProjectComment(
      id: 'c-${const Uuid().v4()}',
      projectId: projectId,
      authorId: me.id,
      text: text.trim(),
      createdAt: DateTime.now(),
      author: me,
    );
    _db.comments.add(comment);
    return comment;
  }

  @override
  Future<void> rate(String projectId, int score, String? comment) async {
    final p = await getById(projectId);
    if (p == null) return;

    final me = _db.currentUser;

    // Autor e colaboradores não avaliam o próprio projeto.
    if (p.involves(me.id)) return;

    // Uma avaliação ativa por usuário por projeto: editar atualiza a
    // existente, nunca cria outra — e não concede XP novamente.
    final alreadyRated = _db.ratings.any(
        (r) => r.projectId == projectId && r.userId == me.id);

    _db.ratings.removeWhere(
        (r) => r.projectId == projectId && r.userId == me.id);
    _db.ratings.add(Rating(
      id: 'r-${const Uuid().v4()}',
      projectId: projectId,
      userId: me.id,
      score: score,
      comment: comment,
      createdAt: DateTime.now(),
    ));

    // XP de quem AVALIA: apenas na primeira avaliação válida (anti-farm).
    if (!alreadyRated) {
      grantXp(_db, me.id, LevelMath.xpPerEvaluation,
          'Avaliou "${p.title}"',
          projectId: projectId);
    }

    // Recalcula média e XP do autor (SPEC §4).
    final all =
        _db.ratings.where((r) => r.projectId == projectId).toList();
    final avg = all.fold<double>(0, (s, r) => s + r.score) / all.length;

    final oldXp = LevelMath.xpForRatingAvg(p.ratingAvg);
    final newXp = LevelMath.xpForRatingAvg(avg);
    final delta = newXp - oldXp;

    _replace(p.copyWith(
      ratingAvg: double.parse(avg.toStringAsFixed(1)),
      ratingCount: all.length,
    ));

    if (delta != 0 && p.authorId != me.id) {
      final i = _db.users.indexWhere((u) => u.id == p.authorId);
      if (i >= 0) {
        _db.users[i] =
            _db.users[i].copyWith(xpTotal: _db.users[i].xpTotal + delta);
      }
      _db.xpEvents.insert(
        0,
        XpEvent(
          id: 'x-${const Uuid().v4()}',
          userId: p.authorId,
          amount: delta,
          reason:
              'Projeto "${p.title}" — avaliação média ${avg.toStringAsFixed(1).replaceAll('.', ',')}',
          projectId: projectId,
          createdAt: DateTime.now(),
        ),
      );
    }

    // A média mudou: reavalia badges do autor (Mente Brilhante,
    // The Thinker, Eu tenho e você?...).
    BadgeSync.run(_db, p.authorId);

    // Notifica autor e colaboradores sobre a avaliação (§14–§15).
    // Editar a avaliação substitui a notificação anterior do mesmo
    // avaliador — nunca duplica (§15).
    _db.notifications.removeWhere((n) =>
        n.type == NotificationType.projectRating &&
        n.actorUserId == me.id &&
        n.referenceId == projectId);
    final recipients = <String>{
      p.authorId,
      ...p.collaborators.map((c) => c.id),
    }..remove(me.id);
    for (final recipientId in recipients) {
      _db.pushNotification(AppNotification(
        id: 'n-${const Uuid().v4()}',
        recipientUserId: recipientId,
        type: NotificationType.projectRating,
        actorUserId: me.id,
        referenceId: projectId,
        title: 'Projeto avaliado',
        message:
            '${me.name} avaliou seu projeto "${p.title}" com ${score.toStringAsFixed(1).replaceAll('.', ',')}.',
        createdAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<List<Rating>> ratings(String projectId) async {
    final list =
        _db.ratings.where((r) => r.projectId == projectId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final r in list)
        Rating(
          id: r.id,
          projectId: r.projectId,
          userId: r.userId,
          score: r.score,
          comment: r.comment,
          createdAt: r.createdAt,
          author: _db.users.firstWhere((u) => u.id == r.userId),
        ),
    ];
  }

  @override
  Future<List<UserProfile>> searchUsers(String query) async {
    final q = query.toLowerCase();
    return _db.users
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  @override
  Future<Project?> lastEditedProject(String userId) async {
    final mine = _db.projects.where((p) => p.authorId == userId).toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    if (mine.isEmpty) return null;
    // Prioriza um projeto em andamento; se todos estiverem concluídos,
    // mostra o mais recente mesmo assim.
    for (final p in mine) {
      if (!p.isCompleted) return p;
    }
    return mine.first;
  }
}

class MockRankingRepository implements RankingRepository {
  MockRankingRepository(this._db);

  final MockDatabase _db;

  @override
  Future<List<LeaderboardEntry>> leaderboard({
    String scope = 'global',
    RankTier? rankFilter,
  }) async {
    var users = [..._db.users]
      ..sort((a, b) => b.xpTotal.compareTo(a.xpTotal));

    final me = _db.currentUser;
    if (scope == 'escola') {
      // Filtro "Minha escola" por ID de escola — nunca por nome (§10).
      final mySchool = me.schoolId;
      if (mySchool == null) return [];
      users = users.where((u) => u.schoolId == mySchool).toList();
    }

    final entries = <LeaderboardEntry>[
      for (var i = 0; i < users.length; i++)
        LeaderboardEntry(
          position: i + 1,
          user: users[i],
          rank: LevelMath.rankForXp(users[i].xpTotal),
          projectCount: _db.projects
              .where((p) => p.authorId == users[i].id)
              .length,
          ratingAvg: _avgOf(users[i].id),
          xpTotal: users[i].xpTotal,
          isCurrentUser: users[i].id == me.id,
        ),
    ];

    if (rankFilter != null) {
      return entries.where((e) => e.rank == rankFilter).toList();
    }
    return entries;
  }

  /// Média real do usuário (rodada 6, §40): somatório de TODAS as
  /// avaliações recebidas pelos projetos dele ÷ quantidade total —
  /// nunca média de médias (um projeto com 1 nota 10 não pode pesar
  /// o mesmo que um com 20 notas 6).
  double _avgOf(String userId) {
    final projectIds = _db.projects
        .where((p) => p.authorId == userId)
        .map((p) => p.id)
        .toSet();
    final rs =
        _db.ratings.where((r) => projectIds.contains(r.projectId)).toList();
    if (rs.isEmpty) return 0;
    return rs.fold<int>(0, (s, r) => s + r.score) / rs.length;
  }
}

// ---------------------------------------------------------------------------
// Helpers de regras de negócio (mock) — centralizados, nunca na UI.
// ---------------------------------------------------------------------------

/// Concede XP a um usuário e registra o evento (XP nunca é removido).
void grantXp(MockDatabase db, String userId, int amount, String reason,
    {String? projectId}) {
  final i = db.users.indexWhere((u) => u.id == userId);
  if (i < 0) return;
  db.users[i] = db.users[i].copyWith(xpTotal: db.users[i].xpTotal + amount);
  db.xpEvents.insert(
    0,
    XpEvent(
      id: 'x-${const Uuid().v4()}',
      userId: userId,
      amount: amount,
      reason: reason,
      projectId: projectId,
      createdAt: DateTime.now(),
    ),
  );
}

/// Reavalia as condições de todos os badges de um usuário e persiste
/// novos desbloqueios (cada badge desbloqueia uma única vez).
class BadgeSync {
  BadgeSync._();

  static int acceptedAnswersOf(MockDatabase db, String userId) =>
      db.materialAnswers.where((a) => a.authorId == userId && a.isAccepted).length;

  static List<double> authorAverages(MockDatabase db, String userId) => [
        for (final p in db.projects.where((p) => p.authorId == userId))
          if (p.ratingCount > 0) p.ratingAvg,
      ];

  static int materialPostsOf(MockDatabase db, String userId) =>
      db.materialPosts.where((p) => p.authorId == userId).length;

  /// Retorna o estado de todos os badges, persistindo novos desbloqueios.
  static List<UserBadge> evaluate(MockDatabase db, String userId) {
    final averages = authorAverages(db, userId);
    final posts = materialPostsOf(db, userId);
    final accepted = acceptedAnswersOf(db, userId);
    final unlocks = db.badgeUnlocks.putIfAbsent(userId, () => {});

    return [
      for (final def in BadgeService.definitions)
        () {
          final progress = BadgeService.progressOf(
            def.id,
            projectAverages: averages,
            materialPosts: posts,
            acceptedAnswers: accepted,
          );
          if (progress >= def.target && !unlocks.containsKey(def.id)) {
            unlocks[def.id] = DateTime.now();
          }
          return UserBadge(
            definition: def,
            progress: progress > def.target ? def.target : progress,
            unlockedAt: unlocks[def.id],
          );
        }(),
    ];
  }

  /// Atalho para disparar a reavaliação após um evento relevante.
  static void run(MockDatabase db, String userId) => evaluate(db, userId);
}

/// Badges em memória.
class MockBadgeRepository implements BadgeRepository {
  MockBadgeRepository(this._db);

  final MockDatabase _db;

  @override
  Future<List<UserBadge>> badgesOf(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return BadgeSync.evaluate(_db, userId);
  }
}

/// Materiais em memória: postagens, respostas e seleção pela moderação.
class MockMaterialRepository implements MaterialRepository {
  MockMaterialRepository(this._db);

  final MockDatabase _db;

  UserProfile? _user(String id) {
    for (final u in _db.users) {
      if (u.id == id) return u;
    }
    return null;
  }

  MaterialPost _withAuthor(MaterialPost p) => MaterialPost(
        id: p.id,
        authorId: p.authorId,
        title: p.title,
        content: p.content,
        subject: p.subject,
        kind: p.kind,
        acceptedAnswerId: p.acceptedAnswerId,
        answerCount: p.answerCount,
        author: _user(p.authorId),
        createdAt: p.createdAt,
      );

  @override
  Future<List<MaterialPost>> listPosts({
    String subject = 'Todos',
    MaterialPostKind? kind,
    String query = '',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    var result = [..._db.materialPosts];
    if (subject != 'Todos') {
      result = result.where((p) => p.subject == subject).toList();
    }
    if (kind != null) {
      result = result.where((p) => p.kind == kind).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              p.content.toLowerCase().contains(q))
          .toList();
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [for (final p in result) _withAuthor(p)];
  }

  @override
  Future<MaterialPost?> getPost(String id) async {
    for (final p in _db.materialPosts) {
      if (p.id == id) return _withAuthor(p);
    }
    return null;
  }

  @override
  Future<List<MaterialAnswer>> answersOf(String postId) async {
    final list = _db.materialAnswers
        .where((a) => a.postId == postId)
        .map((a) => MaterialAnswer(
              id: a.id,
              postId: a.postId,
              authorId: a.authorId,
              content: a.content,
              isAccepted: a.isAccepted,
              markedBy: a.markedBy,
              markedAt: a.markedAt,
              author: _user(a.authorId),
              createdAt: a.createdAt,
            ))
        .toList();
    // Melhor resposta primeiro, depois por data.
    list.sort((a, b) {
      if (a.isAccepted != b.isAccepted) return a.isAccepted ? -1 : 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  @override
  Future<MaterialPost> createPost({
    required String title,
    required String content,
    required String subject,
    required MaterialPostKind kind,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final me = _db.currentUser;
    final post = MaterialPost(
      id: 'm-${const Uuid().v4()}',
      authorId: me.id,
      title: title,
      content: content,
      subject: subject,
      kind: kind,
      createdAt: DateTime.now(),
    );
    _db.materialPosts.insert(0, post);
    BadgeSync.run(_db, me.id); // ex.: Aluno Aplicado I
    return _withAuthor(post);
  }

  @override
  Future<MaterialAnswer> answer(String postId, String content) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final me = _db.currentUser;
    final ans = MaterialAnswer(
      id: 'ma-${const Uuid().v4()}',
      postId: postId,
      authorId: me.id,
      content: content,
      author: me,
      createdAt: DateTime.now(),
    );
    _db.materialAnswers.add(ans);
    final i = _db.materialPosts.indexWhere((p) => p.id == postId);
    if (i >= 0) {
      _db.materialPosts[i] =
          _db.materialPosts[i].copyWith(answerCount: _db.materialPosts[i].answerCount + 1);
    }
    return ans;
  }

  @override
  Future<void> selectBestAnswer(String postId, String? answerId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final me = _db.currentUser;

    // Permissão validada na camada de dados via PermissionService (§35,
    // §47). No backend real: RLS + validação server-side. Esconder o
    // botão na UI é apenas experiência, NÃO segurança.
    if (!PermissionService.canMarkAcceptedAnswer(me)) return;

    final postIndex = _db.materialPosts.indexWhere((p) => p.id == postId);
    if (postIndex < 0) return;

    // Autores afetados para reavaliação de badges/estatísticas.
    final affected = <String>{};

    for (var i = 0; i < _db.materialAnswers.length; i++) {
      final a = _db.materialAnswers[i];
      if (a.postId != postId) continue;
      final isTarget = answerId != null && a.id == answerId;
      if (a.isAccepted != isTarget) {
        affected.add(a.authorId);
        _db.materialAnswers[i] = isTarget
            ? a.copyWith(
                isAccepted: true, markedBy: me.id, markedAt: DateTime.now())
            : a.copyWith(clearMark: true);
      }
    }

    _db.materialPosts[postIndex] = answerId == null
        ? _db.materialPosts[postIndex].copyWith(clearAccepted: true)
        : _db.materialPosts[postIndex].copyWith(acceptedAnswerId: answerId);

    // Aluno Aplicado II / The Mastermind: recomputa do estado real
    // (nunca incrementa contador a cada clique — evita farm/exploit).
    for (final uid in affected) {
      BadgeSync.run(_db, uid);
    }
  }
}

/// Mensagens diretas e em grupo em memória (§20–§26).
class MockMessagingRepository implements MessagingRepository {
  MockMessagingRepository(this._db);

  final MockDatabase _db;

  String get _me => _db.currentUser.id;

  int _unreadOf(String conversationId) => _db.messages
      .where((m) =>
          m.conversationId == conversationId && m.senderId != _me && !m.read)
      .length;

  UserProfile _user(String id) =>
      _db.users.firstWhere((u) => u.id == id, orElse: () => _db.users.first);

  bool _isMemberOf(String conversationId) => _db.groupMembers
      .any((m) => m.conversationId == conversationId && m.userId == _me);

  Conversation _hydrate(Conversation c) {
    final msgs = _db.messages
        .where((m) => m.conversationId == c.id)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    // Participantes são sempre resolvidos da fonte única (_db.users),
    // para que mudanças de nome/foto reflitam nas conversas (§2).
    final participants = c.isGroup
        ? [
            for (final m in _db.groupMembers.where(
                (m) => m.conversationId == c.id))
              _user(m.userId),
          ]
        : [for (final p in c.participants) _user(p.id)];
    return Conversation(
      id: c.id,
      type: c.type,
      name: c.name,
      imageUrl: c.imageUrl,
      createdBy: c.createdBy,
      participants: participants,
      lastMessage: msgs.isEmpty ? null : msgs.last.content,
      lastMessageAt: msgs.isEmpty ? null : msgs.last.createdAt,
      unreadCount: _unreadOf(c.id),
    );
  }

  @override
  Future<List<Conversation>> conversations() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Diretas: ambos os participantes. Grupos: apenas se eu for membro
    // (convite pendente NÃO mostra o grupo na lista).
    final list = [
      for (final c in _db.conversations)
        if (!c.isGroup || _isMemberOf(c.id)) _hydrate(c),
    ];
    list.sort((a, b) => (b.lastMessageAt ?? DateTime(0))
        .compareTo(a.lastMessageAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<Conversation> getOrCreateConversation(String otherUserId) async {
    // Nunca duplica a conversa DIRETA do mesmo par de usuários.
    for (final c in _db.conversations) {
      if (c.isGroup) continue;
      final ids = c.participants.map((u) => u.id).toSet();
      if (ids.contains(_me) && ids.contains(otherUserId)) {
        return _hydrate(c);
      }
    }
    final other = _db.users.firstWhere((u) => u.id == otherUserId);
    final conv = Conversation(
      id: 'c-${const Uuid().v4()}',
      participants: [_db.currentUser, other],
    );
    _db.conversations.add(conv);
    return _hydrate(conv);
  }

  // -- Grupos ---------------------------------------------------------------

  @override
  Future<Conversation> createGroup({
    required String name,
    String? imageUrl,
    required List<String> invitedUserIds,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final me = _db.currentUser;
    final conv = Conversation(
      id: 'g-${const Uuid().v4()}',
      type: ConversationType.group,
      name: name,
      imageUrl: imageUrl,
      createdBy: me.id,
      participants: [me],
    );
    _db.conversations.add(conv);
    // Criador entra como owner imediatamente.
    _db.groupMembers.add(GroupMember(
      conversationId: conv.id,
      userId: me.id,
      role: GroupRole.owner,
      joinedAt: DateTime.now(),
    ));
    // Selecionados recebem CONVITE — ninguém entra automaticamente (§21).
    for (final uid in invitedUserIds.toSet()) {
      if (uid == me.id) continue;
      _db.groupInvites.add(GroupInvite(
        id: 'gi-${const Uuid().v4()}',
        groupId: conv.id,
        inviterId: me.id,
        invitedUserId: uid,
        token: const Uuid().v4(),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      ));
    }
    return _hydrate(conv);
  }

  @override
  Future<List<GroupInvite>> myPendingInvites() async {
    return _db.groupInvites
        .where((i) =>
            i.invitedUserId == _me &&
            i.isPending &&
            i.expiresAt.isAfter(DateTime.now()))
        .toList();
  }

  @override
  Future<({Conversation group, UserProfile inviter})> inviteContext(
      GroupInvite invite) async {
    final group = _db.conversations.firstWhere((c) => c.id == invite.groupId);
    return (group: _hydrate(group), inviter: _user(invite.inviterId));
  }

  /// Sem convites duplicados: já membro ou convite pendente existente.
  bool hasInviteOrMembership(String groupId, String userId) {
    final isMember = _db.groupMembers
        .any((m) => m.conversationId == groupId && m.userId == userId);
    if (isMember) return true;
    return _db.groupInvites.any((i) =>
        i.groupId == groupId &&
        i.invitedUserId == userId &&
        i.isPending);
  }

  @override
  Future<Conversation> acceptInvite(String inviteId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final i = _db.groupInvites.indexWhere((x) => x.id == inviteId);
    if (i < 0) throw StateError('Convite não encontrado.');
    final invite = _db.groupInvites[i];
    // Apenas o convidado pode aceitar o próprio convite (§25).
    if (invite.invitedUserId != _me || !invite.isPending) {
      throw StateError('Este convite não pode ser aceito.');
    }
    _db.groupInvites[i] = GroupInvite(
      id: invite.id,
      groupId: invite.groupId,
      inviterId: invite.inviterId,
      invitedUserId: invite.invitedUserId,
      token: invite.token,
      status: InviteStatus.accepted,
      createdAt: invite.createdAt,
      expiresAt: invite.expiresAt,
    );
    _db.groupMembers.add(GroupMember(
      conversationId: invite.groupId,
      userId: _me,
      joinedAt: DateTime.now(),
    ));
    final group =
        _db.conversations.firstWhere((c) => c.id == invite.groupId);
    return _hydrate(group);
  }

  @override
  Future<void> ignoreInvite(String inviteId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final i = _db.groupInvites.indexWhere((x) => x.id == inviteId);
    if (i < 0) return;
    final invite = _db.groupInvites[i];
    if (invite.invitedUserId != _me || !invite.isPending) return;
    _db.groupInvites[i] = GroupInvite(
      id: invite.id,
      groupId: invite.groupId,
      inviterId: invite.inviterId,
      invitedUserId: invite.invitedUserId,
      token: invite.token,
      status: InviteStatus.ignored,
      createdAt: invite.createdAt,
      expiresAt: invite.expiresAt,
    );
  }

  @override
  Future<GroupRole?> myRoleIn(String conversationId) async {
    for (final m in _db.groupMembers) {
      if (m.conversationId == conversationId && m.userId == _me) {
        return m.role;
      }
    }
    return null;
  }

  @override
  Future<List<Message>> messages(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final list = _db.messages
        .where((m) => m.conversationId == conversationId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<Message> sendMessage(String conversationId, String content) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final msg = Message(
      id: 'msg-${const Uuid().v4()}',
      conversationId: conversationId,
      senderId: _me,
      content: content,
      read: true,
      createdAt: DateTime.now(),
    );
    _db.messages.add(msg);
    _notifyNewMessage(conversationId);
    return msg;
  }

  /// Notifica os participantes sobre mensagem nova (§12–§13).
  /// Direta: uma notificação por remetente. Grupo: agrega as não lidas
  /// em "N novas mensagens em …" para não lotar o painel (§13).
  void _notifyNewMessage(String conversationId) {
    final conv = _db.conversations.firstWhere((c) => c.id == conversationId);
    final me = _db.currentUser;
    if (conv.isGroup) {
      final memberIds = _db.groupMembers
          .where((m) => m.conversationId == conversationId)
          .map((m) => m.userId)
          .where((id) => id != _me);
      for (final userId in memberIds) {
        final i = _db.notifications.indexWhere((n) =>
            n.recipientUserId == userId &&
            n.type == NotificationType.groupMessage &&
            n.referenceId == conversationId &&
            !n.isRead);
        if (i >= 0) {
          final n = _db.notifications[i];
          final count = n.count + 1;
          _db.notifications[i] = n.copyWith(
            message: '$count novas mensagens em ${conv.name}',
            count: count,
            createdAt: DateTime.now(),
          );
        } else {
          _db.pushNotification(AppNotification(
            id: 'n-${const Uuid().v4()}',
            recipientUserId: userId,
            type: NotificationType.groupMessage,
            actorUserId: _me,
            referenceId: conversationId,
            title: conv.name ?? 'Grupo',
            message: '${me.name} enviou uma mensagem em ${conv.name}.',
            createdAt: DateTime.now(),
          ));
        }
      }
    } else {
      final others =
          conv.participants.map((u) => u.id).where((id) => id != _me);
      for (final userId in others) {
        _db.pushNotification(AppNotification(
          id: 'n-${const Uuid().v4()}',
          recipientUserId: userId,
          type: NotificationType.message,
          actorUserId: _me,
          referenceId: conversationId,
          title: 'Nova mensagem',
          message: '${me.name} enviou uma mensagem para você.',
          createdAt: DateTime.now(),
        ));
      }
    }
  }

  @override
  Future<void> markRead(String conversationId) async {
    for (var i = 0; i < _db.messages.length; i++) {
      final m = _db.messages[i];
      if (m.conversationId == conversationId &&
          m.senderId != _me &&
          !m.read) {
        _db.messages[i] = Message(
          id: m.id,
          conversationId: m.conversationId,
          senderId: m.senderId,
          content: m.content,
          read: true,
          createdAt: m.createdAt,
        );
      }
    }
  }
}

/// Escolas e comunicados escolares em memória (§8, §37–§40).
class MockSchoolRepository implements SchoolRepository {
  MockSchoolRepository(this._db);

  final MockDatabase _db;

  @override
  Future<List<School>> listSchools({String query = ''}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    var result = _db.schools.where((s) => s.active).toList();
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      result = result
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.city.toLowerCase().contains(q) ||
              s.state.toLowerCase().contains(q))
          .toList();
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  @override
  Future<School?> getById(String id) async {
    for (final s in _db.schools) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<List<SchoolAnnouncement>> announcementsOf(String schoolId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final list = _db.schoolAnnouncements
        .where((a) => a.schoolId == schoolId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<SchoolAnnouncement> createAnnouncement({
    required String schoolId,
    required String title,
    String? subtitle,
    required String content,
    required AnnouncementCategory category,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final me = _db.currentUser;
    // Permissão validada na camada de dados — esconder o botão na UI
    // não é segurança (§47). No backend real: RLS.
    if (!PermissionService.canCreateSchoolAnnouncement(me)) {
      throw StateError('Apenas Developers podem publicar comunicados.');
    }
    final ann = SchoolAnnouncement(
      id: 'sa-${const Uuid().v4()}',
      schoolId: schoolId,
      authorId: me.id,
      title: title,
      subtitle: subtitle?.isEmpty ?? true ? null : subtitle,
      content: content,
      category: category,
      createdAt: DateTime.now(),
    );
    _db.schoolAnnouncements.insert(0, ann);
    return ann;
  }

  @override
  Future<void> updateAnnouncement(
    String id, {
    String? title,
    String? subtitle,
    String? content,
    AnnouncementCategory? category,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final me = _db.currentUser;
    if (!PermissionService.canEditSchoolAnnouncement(me)) return;
    final i = _db.schoolAnnouncements.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final old = _db.schoolAnnouncements[i];
    _db.schoolAnnouncements[i] = SchoolAnnouncement(
      id: old.id,
      schoolId: old.schoolId,
      authorId: old.authorId,
      title: title ?? old.title,
      subtitle: subtitle ?? old.subtitle,
      content: content ?? old.content,
      category: category ?? old.category,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final me = _db.currentUser;
    if (!PermissionService.canDeleteSchoolAnnouncement(me)) return;
    _db.schoolAnnouncements.removeWhere((a) => a.id == id);
  }

  @override
  Future<SchoolStats> stats(String schoolId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    // Alunos: usuários únicos com schoolId == escola (§28–§29).
    final members = _db.users.where((u) => u.schoolId == schoolId).toList();
    final memberIds = members.map((u) => u.id).toSet();
    // Projetos: conta pelo AUTOR principal — colaboradores de outras
    // escolas não duplicam a contagem (§33).
    final projects =
        _db.projects.where((p) => memberIds.contains(p.authorId)).toList();
    // Média: somatório de TODAS as avaliações válidas ÷ quantidade
    // (nunca média de médias — §35); 0 quando não há avaliações (§36).
    final projectIds = projects.map((p) => p.id).toSet();
    final ratings =
        _db.ratings.where((r) => projectIds.contains(r.projectId)).toList();
    final avg = ratings.isEmpty
        ? 0.0
        : ratings.fold<int>(0, (sum, r) => sum + r.score) / ratings.length;
    return SchoolStats(
      studentCount: members.length,
      projectCount: projects.length,
      ratingAvg: avg,
      ratingCount: ratings.length,
    );
  }
}

/// Pesquisa global em memória (§27–§33): usuários, projetos e materiais,
/// com correspondência parcial case-insensitive.
class MockSearchRepository implements SearchRepository {
  MockSearchRepository(this._db);

  final MockDatabase _db;

  @override
  Future<GlobalSearchResults> search(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const GlobalSearchResults();
    return GlobalSearchResults(
      users: _db.users
          .where((u) =>
              u.name.toLowerCase().contains(q) ||
              u.username.toLowerCase().contains(q))
          .toList(),
      projects: _db.projects
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              p.subtitle.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              (p.textContent?.toLowerCase().contains(q) ?? false))
          .toList(),
      materials: _db.materialPosts
          .where((m) =>
              m.title.toLowerCase().contains(q) ||
              m.content.toLowerCase().contains(q))
          .toList(),
    );
  }
}

/// Notificações em memória (rodada 4, §11–§21). Quando o Supabase for
/// conectado, o SupabaseNotificationRepository assume sem mudar a UI.
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository(this._db);

  final MockDatabase _db;

  @override
  Future<List<AppNotification>> notificationsOf(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final list = _db.notifications
        .where((n) => n.recipientUserId == userId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<int> unreadCount(String userId) async {
    return _db.notifications
        .where((n) => n.recipientUserId == userId && !n.isRead)
        .length;
  }

  @override
  Future<void> markRead(String notificationId) async {
    final i = _db.notifications.indexWhere((n) => n.id == notificationId);
    if (i >= 0 && !(_db.notifications[i].isRead)) {
      _db.notifications[i] =
          _db.notifications[i].copyWith(readAt: DateTime.now());
    }
  }

  @override
  Future<void> markAllRead(String userId) async {
    for (var i = 0; i < _db.notifications.length; i++) {
      final n = _db.notifications[i];
      if (n.recipientUserId == userId && !n.isRead) {
        _db.notifications[i] = n.copyWith(readAt: DateTime.now());
      }
    }
  }
}

/// Biblioteca local (rodada 4, §37). Guarda apenas a relação
/// userId ↔ projectId (§32) — nunca uma cópia do projeto.
/// Será substituída pelo SupabaseSavedProjectsRepository na conexão.
class LocalSavedProjectsRepository implements SavedProjectsRepository {
  LocalSavedProjectsRepository(this._db);

  final MockDatabase _db;

  @override
  Future<List<SavedProject>> savedRelations(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final list =
        _db.savedProjects.where((s) => s.userId == userId).toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return list;
  }

  @override
  Future<bool> isSaved(String userId, String projectId) async {
    return _db.savedProjects.any((s) => s.matches(userId, projectId));
  }

  @override
  Future<bool> toggle(String userId, String projectId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final saved = _db.toggleSaved(userId, projectId);
    // Mantém o flag savedByMe dos cards em sincronia com a relação.
    final i = _db.projects.indexWhere((p) => p.id == projectId);
    if (i >= 0) {
      _db.projects[i] = _db.projects[i].copyWith(savedByMe: saved);
    }
    return saved;
  }
}

/// Denúncias de projetos em memória (rodada 6). Reportar nunca remove
/// o projeto — apenas enfileira para a moderação (Developers).
class LocalReportRepository implements ReportRepository {
  LocalReportRepository(this._db);

  final MockDatabase _db;

  @override
  Future<ProjectReport> reportProject(
    String projectId, {
    required ReportReason reason,
    String? description,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final me = _db.currentUser;
    final project =
        _db.projects.where((p) => p.id == projectId).firstOrNull;
    if (project == null) {
      throw StateError('Projeto não encontrado.');
    }
    // Quem participa do projeto não o denuncia (PermissionService).
    if (!PermissionService.canReportProject(me, project)) {
      throw StateError('Você não pode denunciar um projeto do qual participa.');
    }
    // Sem denúncias pendentes duplicadas do mesmo usuário para o mesmo
    // projeto — retorna a que já está na fila.
    final existing = _db.reports.where((r) =>
        r.projectId == projectId &&
        r.reporterUserId == me.id &&
        r.status == ReportStatus.pending);
    if (existing.isNotEmpty) return existing.first;

    final report = ProjectReport(
      id: 'rep-${const Uuid().v4()}',
      projectId: projectId,
      reporterUserId: me.id,
      reason: reason,
      description: description?.trim().isEmpty ?? true
          ? null
          : description!.trim(),
      createdAt: DateTime.now(),
    );
    _db.reports.add(report);
    return report;
  }

  @override
  Future<List<ProjectReport>> myPendingReports() async {
    final me = _db.currentUser;
    return _db.reports
        .where((r) =>
            r.reporterUserId == me.id && r.status == ReportStatus.pending)
        .toList();
  }

  @override
  Future<List<ProjectReport>> pendingReports() async {
    // Fila da moderação: somente Developers (RLS no Supabase).
    if (!PermissionService.canReviewProjectReport(_db.currentUser)) {
      throw StateError('Apenas Developers podem ver a fila de denúncias.');
    }
    return _db.reports
        .where((r) => r.status == ReportStatus.pending)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> reviewReport(String reportId, ReportStatus result) async {
    if (!PermissionService.canReviewProjectReport(_db.currentUser)) return;
    final i = _db.reports.indexWhere((r) => r.id == reportId);
    if (i < 0) return;
    final old = _db.reports[i];
    _db.reports[i] = ProjectReport(
      id: old.id,
      projectId: old.projectId,
      reporterUserId: old.reporterUserId,
      reason: old.reason,
      description: old.description,
      status: result,
      createdAt: old.createdAt,
      reviewedAt: DateTime.now(),
      reviewedBy: _db.currentUser.id,
    );
  }
}
