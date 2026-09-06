import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/badge_service.dart';
import '../../models/models.dart';
import '../repositories.dart';

/// Implementações Supabase (SPEC §8).
/// Ativadas com --dart-define=USE_MOCK=false (ver README).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  UserProfile? get currentUser => null; // preenchido via watchCurrentUser

  @override
  Stream<UserProfile?> watchCurrentUser() {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) return null;
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return _profileFromRow(row);
    });
  }

  @override
  Future<UserProfile> signIn(
      {required String email, required String password}) async {
    final res = await _client.auth
        .signInWithPassword(email: email, password: password);
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', res.user!.id)
        .single();
    return _profileFromRow(row);
  }

  @override
  Future<UserProfile> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'username': username},
    );
    // Sem sessão = o projeto exige confirmação de e-mail. A conta já
    // existe; o usuário precisa confirmar antes de entrar.
    if (res.session == null) {
      throw const EmailConfirmationRequiredException();
    }
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', res.user!.id)
        .single();
    return _profileFromRow(row);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  static UserProfile _profileFromRow(Map<String, dynamic> row) =>
      profileFromRow(row);
}

/// Mapeia uma linha de `profiles` para UserProfile (compartilhado).
/// O cargo vem EXCLUSIVAMENTE da coluna `role` da tabela (definida no
/// backend) — nunca de e-mail ou escolha do usuário (§44–§46).
UserProfile profileFromRow(Map<String, dynamic> row) => UserProfile(
      id: row['id'] as String,
      name: row['name'] as String,
      username: row['username'] as String,
      avatarUrl: row['avatar_url'] as String?,
      xpTotal: (row['xp_total'] as num?)?.toInt() ?? 0,
      schoolId: row['school_id'] as String?,
      bio: row['bio'] as String?,
      instagram: row['instagram'] as String?,
      xHandle: row['x_handle'] as String?,
      contactNumber: row['contact_number'] as String?,
      role: UserRole.values.firstWhere(
        (r) => r.name == row['role'],
        orElse: () => UserRole.user,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
    );

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<UserProfile?> getById(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return SupabaseAuthRepository._profileFromRow(row);
  }

  @override
  Future<UserProfile?> getByUsername(String username) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('username', username)
        .maybeSingle();
    if (row == null) return null;
    return SupabaseAuthRepository._profileFromRow(row);
  }

  @override
  Future<UserStats> stats(String userId) async {
    final row = await _client
        .rpc('user_stats', params: {'p_user_id': userId})
        .single();
    return UserStats(
      projectsPublished: (row['projects_published'] as num).toInt(),
      ratingsReceived: (row['ratings_received'] as num).toInt(),
      likesReceived: (row['likes_received'] as num).toInt(),
      ratingAvg: (row['rating_avg'] as num).toDouble(),
      xpTotal: (row['xp_total'] as num).toInt(),
    );
  }

  @override
  Future<List<XpEvent>> xpEvents(String userId, {int limit = 10}) async {
    final rows = await _client
        .from('xp_events')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return [
      for (final r in rows)
        XpEvent(
          id: r['id'] as String,
          userId: r['user_id'] as String,
          amount: (r['amount'] as num).toInt(),
          reason: r['reason'] as String,
          projectId: r['project_id'] as String?,
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
    ];
  }

  @override
  Future<RankTier> rankOf(String userId) async {
    final row = await _client
        .rpc('rank_of', params: {'p_user_id': userId})
        .single();
    return _tierFromString(row['rank'] as String);
  }

  @override
  Future<int> positionInRank(String userId) async {
    final row = await _client
        .rpc('position_in_rank', params: {'p_user_id': userId})
        .single();
    return (row['position'] as num).toInt();
  }

  @override
  Future<List<Project>> projectsOf(String userId) async {
    final rows = await _client
        .from('projects')
        .select('*, project_media(*)')
        .eq('author_id', userId)
        .order('created_at', ascending: false);
    return [for (final r in rows) SupabaseProjectRepository.projectFromRow(r)];
  }

  /// Atualiza o perfil (§2). A coluna `role` NUNCA é enviada — o cargo
  /// é definido no backend e protegido por RLS (§44–§46).
  @override
  Future<UserProfile> updateProfile(ProfileUpdate update) async {
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from('profiles')
        .update({
          if (update.name != null) 'name': update.name,
          if (update.avatarUrl != null) 'avatar_url': update.avatarUrl,
          if (update.clearAvatar) 'avatar_url': null,
          if (update.bio != null) 'bio': update.bio,
          if (update.instagram != null) 'instagram': update.instagram,
          if (update.xHandle != null) 'x_handle': update.xHandle,
          if (update.contactNumber != null)
            'contact_number': update.contactNumber,
          if (update.schoolId != null) 'school_id': update.schoolId,
          if (update.clearSchool) 'school_id': null,
        })
        .eq('id', uid)
        .select()
        .single();
    return profileFromRow(row);
  }

  static RankTier _tierFromString(String s) => switch (s) {
        'sublime' => RankTier.sublime,
        'diamante' => RankTier.diamante,
        'esmeralda' => RankTier.esmeralda,
        'ouro' => RankTier.ouro,
        _ => RankTier.bronze,
      };
}

class SupabaseProjectRepository implements ProjectRepository {
  SupabaseProjectRepository(this._client);

  final SupabaseClient _client;

  static Project projectFromRow(Map<String, dynamic> row) => Project(
        id: row['id'] as String,
        authorId: row['author_id'] as String,
        title: row['title'] as String,
        subtitle: row['subtitle'] as String,
        description: row['description'] as String,
        category: ProjectCategory.values.firstWhere(
          (c) => c.name == row['category'],
          orElse: () => ProjectCategory.outros,
        ),
        type: ProjectType.values.firstWhere(
          (t) => t.name == row['type'],
          orElse: () => ProjectType.estudantil,
        ),
        tags: [for (final t in (row['tags'] as List? ?? [])) '$t'],
        media: [
          for (final m in (row['project_media'] as List? ?? []))
            ProjectMedia(
              id: m['id'] as String,
              url: m['url'] as String,
              kind: ProjectMediaKind.values.firstWhere(
                (k) => k.name == m['kind'],
                orElse: () => ProjectMediaKind.image,
              ),
              label: m['label'] as String?,
            ),
        ],
        likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
        commentCount: (row['comment_count'] as num?)?.toInt() ?? 0,
        saveCount: (row['save_count'] as num?)?.toInt() ?? 0,
        ratingCount: (row['rating_count'] as num?)?.toInt() ?? 0,
        ratingAvg: (row['rating_avg'] as num?)?.toDouble() ?? 0,
        textContent: row['text_content'] as String?,
        cardTone: row['card_tone'] == null
            ? null
            : TextCardTone.values.firstWhere(
                (t) => t.name == row['card_tone'],
                orElse: () => TextCardTone.azul,
              ),
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: row['updated_at'] == null
            ? null
            : DateTime.parse(row['updated_at'] as String),
        completedAt: row['completed_at'] == null
            ? null
            : DateTime.parse(row['completed_at'] as String),
      );

  @override
  Future<List<Project>> list({
    DiscoverTab tab = DiscoverTab.paraVoce,
    ProjectCategory? category,
    String query = '',
    int page = 0,
    int pageSize = 12,
  }) async {
    var q = _client.from('projects').select('*, project_media(*)');

    if (tab == DiscoverTab.estudantis) q = q.eq('type', 'estudantil');
    if (tab == DiscoverTab.autorais) q = q.eq('type', 'autoral');
    if (tab == DiscoverTab.docentes) q = q.eq('type', 'docente');
    if (category != null) q = q.eq('category', category.name);
    if (query.isNotEmpty) q = q.ilike('title', '%$query%');

    final rows = await q
        .order(tab == DiscoverTab.podio ? 'rating_avg' : 'created_at',
            ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);
    return [for (final r in rows) projectFromRow(r)];
  }

  @override
  Future<Project?> getById(String id) async {
    final row = await _client
        .from('projects')
        .select('*, project_media(*)')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : projectFromRow(row);
  }

  @override
  Future<UserProfile?> authorOf(String authorId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', authorId)
        .maybeSingle();
    return row == null ? null : SupabaseAuthRepository._profileFromRow(row);
  }

  @override
  Future<Project> create(ProjectDraft draft) async {
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from('projects')
        .insert({
          'author_id': uid,
          'title': draft.title,
          'subtitle': draft.subtitle,
          'description': draft.description,
          'category': draft.category.name,
          'type': draft.type.name,
          'tags': draft.tags,
          if (draft.textContent != null) 'text_content': draft.textContent,
          if (draft.cardTone != null) 'card_tone': draft.cardTone!.name,
        })
        .select()
        .single();
    final project = projectFromRow({...row, 'project_media': const []});

    if (draft.media.isNotEmpty) {
      await _client.from('project_media').insert([
        for (final m in draft.media)
          {
            'project_id': project.id,
            'url': m.url,
            'kind': m.kind.name,
            'label': m.label,
          },
      ]);
    }
    if (draft.collaboratorIds.isNotEmpty) {
      await _client.from('project_collaborators').insert([
        for (final c in draft.collaboratorIds)
          {'project_id': project.id, 'user_id': c},
      ]);
    }
    return project;
  }

  @override
  Future<void> toggleLike(String projectId) async {
    await _client.rpc('toggle_like', params: {'p_project_id': projectId});
  }

  @override
  Future<void> toggleSave(String projectId) async {
    await _client.rpc('toggle_save', params: {'p_project_id': projectId});
  }

  @override
  Future<void> rate(String projectId, int score, String? comment) async {
    await _client.from('ratings').upsert({
      'project_id': projectId,
      'user_id': _client.auth.currentUser!.id,
      'score': score,
      'comment': comment,
    });
    // XP recalculado por trigger no banco (ver schema.sql).
  }

  @override
  Future<List<Rating>> ratings(String projectId) async {
    final rows = await _client
        .from('ratings')
        .select('*, profiles(*)')
        .eq('project_id', projectId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        Rating(
          id: r['id'] as String,
          projectId: r['project_id'] as String,
          userId: r['user_id'] as String,
          score: (r['score'] as num).toInt(),
          comment: r['comment'] as String?,
          createdAt: DateTime.parse(r['created_at'] as String),
          author: r['profiles'] != null
              ? SupabaseAuthRepository._profileFromRow(
                  r['profiles'] as Map<String, dynamic>)
              : null,
        ),
    ];
  }

  @override
  Future<List<UserProfile>> searchUsers(String query) async {
    final rows = await _client
        .from('profiles')
        .select()
        .or('name.ilike.%$query%,username.ilike.%$query%')
        .limit(8);
    return [
      for (final r in rows) SupabaseAuthRepository._profileFromRow(r)
    ];
  }

  @override
  Future<Project?> lastEditedProject(String userId) async {
    final rows = await _client
        .from('projects')
        .select('*, project_media(*)')
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .limit(10);
    if (rows.isEmpty) return null;
    final projects = [for (final r in rows) projectFromRow(r)];
    for (final p in projects) {
      if (!p.isCompleted) return p;
    }
    return projects.first;
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
    await _client.from('projects').update({
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (subtitle != null) 'subtitle': subtitle.trim(),
      if (description != null) 'description': description.trim(),
      'text_content': ?textContent,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', projectId);

    // Mídia informada = lista completa nova: substitui o repositório
    // de arquivos do projeto (edição aditiva acontece na UI, que manda
    // a lista antiga + novos itens).
    if (media != null) {
      await _client
          .from('project_media')
          .delete()
          .eq('project_id', projectId);
      if (media.isNotEmpty) {
        await _client.from('project_media').insert([
          for (var i = 0; i < media.length; i++)
            {
              'project_id': projectId,
              'url': media[i].url,
              'kind': media[i].kind.name,
              'label': media[i].label,
              'position': i,
            },
        ]);
      }
    }
  }

  @override
  Future<void> setCompleted(String projectId, bool completed) async {
    await _client.from('projects').update({
      'completed_at':
          completed ? DateTime.now().toIso8601String() : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', projectId);
  }

  @override
  Future<List<ProjectComment>> comments(String projectId) async {
    final rows = await _client
        .from('comments')
        .select('*, profiles(*)')
        .eq('project_id', projectId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        ProjectComment(
          id: r['id'] as String,
          projectId: r['project_id'] as String,
          authorId: r['author_id'] as String,
          text: r['text'] as String,
          createdAt: DateTime.parse(r['created_at'] as String),
          author: r['profiles'] != null
              ? SupabaseAuthRepository._profileFromRow(
                  r['profiles'] as Map<String, dynamic>)
              : null,
        ),
    ];
  }

  @override
  Future<ProjectComment> addComment(String projectId, String text) async {
    final row = await _client
        .from('comments')
        .insert({
          'project_id': projectId,
          'author_id': _client.auth.currentUser!.id,
          'text': text.trim(),
        })
        .select('*, profiles(*)')
        .single();
    return ProjectComment(
      id: row['id'] as String,
      projectId: row['project_id'] as String,
      authorId: row['author_id'] as String,
      text: row['text'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      author: row['profiles'] != null
          ? SupabaseAuthRepository._profileFromRow(
              row['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  /// A RLS no banco garante que só o autor principal conclui o delete;
  /// esconder o botão na UI é apenas experiência, nunca segurança.
  /// As relações (mídias, curtidas, salvos, avaliações, comentários,
  /// denúncias) caem em cascata pelos ON DELETE CASCADE do schema.
  @override
  Future<void> deleteProject(String projectId) async {
    await _client.from('projects').delete().eq('id', projectId);
  }

  /// RLS: autor do comentário OU autor do projeto podem excluir.
  /// O contador é atualizado pelo trigger sync_comment_count.
  @override
  Future<void> deleteComment(String commentId) async {
    await _client.from('comments').delete().eq('id', commentId);
  }
}

class SupabaseRankingRepository implements RankingRepository {
  SupabaseRankingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<LeaderboardEntry>> leaderboard({
    String scope = 'global',
    RankTier? rankFilter,
  }) async {
    final rows = await _client.rpc('leaderboard', params: {
      'p_scope': scope,
    });
    final me = _client.auth.currentUser?.id;
    final entries = [
      for (final r in rows)
        LeaderboardEntry(
          position: (r['position'] as num).toInt(),
          user: SupabaseAuthRepository._profileFromRow(
              r['profile'] as Map<String, dynamic>),
          rank: SupabaseProfileRepository._tierFromString(r['rank'] as String),
          projectCount: (r['project_count'] as num).toInt(),
          ratingAvg: (r['rating_avg'] as num).toDouble(),
          xpTotal: (r['xp_total'] as num).toInt(),
          isCurrentUser: (r['profile'] as Map)['id'] == me,
        ),
    ];
    if (rankFilter != null) {
      return entries.where((e) => e.rank == rankFilter).toList();
    }
    return entries;
  }
}

/// Badges via RPC `user_badges` (a condição é avaliada no backend —
/// ver supabase/schema.sql). A UI nunca calcula nem altera desbloqueios.
class SupabaseBadgeRepository implements BadgeRepository {
  SupabaseBadgeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<UserBadge>> badgesOf(String userId) async {
    final rows = await _client
        .rpc('user_badges', params: {'p_user': userId}) as List;
    return [
      for (final r in rows)
        UserBadge(
          definition: BadgeService.definitionOf(BadgeId.values.firstWhere(
            (b) => b.name == r['badge_id'],
            orElse: () => BadgeId.autor,
          )),
          progress: (r['progress'] as num).toInt(),
          unlockedAt: r['unlocked_at'] == null
              ? null
              : DateTime.parse(r['unlocked_at'] as String),
        ),
    ];
  }
}

/// Materiais no Supabase. A seleção de melhor resposta é feita pela RPC
/// `select_best_answer`, que valida o cargo Developer no servidor (§35).
class SupabaseMaterialRepository implements MaterialRepository {
  SupabaseMaterialRepository(this._client);

  final SupabaseClient _client;

  static MaterialPost postFromRow(Map<String, dynamic> row) => MaterialPost(
        id: row['id'] as String,
        authorId: row['author_id'] as String,
        title: row['title'] as String,
        content: row['content'] as String,
        subject: row['subject'] as String,
        kind: MaterialPostKind.values.firstWhere(
          (k) => k.name == row['kind'],
          orElse: () => MaterialPostKind.compartilhamento,
        ),
        acceptedAnswerId: row['accepted_answer_id'] as String?,
        answerCount: (row['answer_count'] as num?)?.toInt() ?? 0,
        author: row['profiles'] == null
            ? null
            : profileFromRow(row['profiles'] as Map<String, dynamic>),
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  MaterialAnswer _answerFromRow(Map<String, dynamic> row) => MaterialAnswer(
        id: row['id'] as String,
        postId: row['post_id'] as String,
        authorId: row['author_id'] as String,
        content: row['content'] as String,
        isAccepted: row['is_accepted'] as bool? ?? false,
        markedBy: row['marked_by'] as String?,
        markedAt: row['marked_at'] == null
            ? null
            : DateTime.parse(row['marked_at'] as String),
        author: row['profiles'] == null
            ? null
            : profileFromRow(row['profiles'] as Map<String, dynamic>),
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  @override
  Future<List<MaterialPost>> listPosts({
    String subject = 'Todos',
    MaterialPostKind? kind,
    String query = '',
  }) async {
    var q = _client.from('material_posts').select('*, profiles(*)');
    if (subject != 'Todos') q = q.eq('subject', subject);
    if (kind != null) q = q.eq('kind', kind.name);
    if (query.isNotEmpty) q = q.ilike('title', '%$query%');
    final rows = await q.order('created_at', ascending: false);
    return [for (final r in rows) postFromRow(r)];
  }

  @override
  Future<MaterialPost?> getPost(String id) async {
    final row = await _client
        .from('material_posts')
        .select('*, profiles(*)')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : postFromRow(row);
  }

  @override
  Future<List<MaterialAnswer>> answersOf(String postId) async {
    final rows = await _client
        .from('material_answers')
        .select('*, profiles(*)')
        .eq('post_id', postId)
        .order('is_accepted', ascending: false)
        .order('created_at');
    return [for (final r in rows) _answerFromRow(r)];
  }

  @override
  Future<MaterialPost> createPost({
    required String title,
    required String content,
    required String subject,
    required MaterialPostKind kind,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from('material_posts')
        .insert({
          'author_id': uid,
          'title': title,
          'content': content,
          'subject': subject,
          'kind': kind.name,
        })
        .select('*, profiles(*)')
        .single();
    await _client.rpc('check_badges', params: {'p_user': uid});
    return postFromRow(row);
  }

  @override
  Future<MaterialAnswer> answer(String postId, String content) async {
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from('material_answers')
        .insert({'post_id': postId, 'author_id': uid, 'content': content})
        .select('*, profiles(*)')
        .single();
    return _answerFromRow(row);
  }

  @override
  Future<void> selectBestAnswer(String postId, String? answerId) async {
    await _client.rpc('select_best_answer', params: {
      'p_post': postId,
      'p_answer': answerId,
    });
  }
}

/// Mensagens diretas no Supabase (sem relação de amizade).
class SupabaseMessagingRepository implements MessagingRepository {
  SupabaseMessagingRepository(this._client);

  final SupabaseClient _client;

  String get _me => _client.auth.currentUser!.id;

  @override
  Future<List<Conversation>> conversations() async {
    final rows = await _client.rpc('my_conversations') as List;
    return [
      for (final r in rows)
        Conversation(
          id: r['id'] as String,
          participants: [
            for (final p in (r['participants'] as List))
              profileFromRow(p as Map<String, dynamic>),
          ],
          lastMessage: r['last_message'] as String?,
          lastMessageAt: r['last_message_at'] == null
              ? null
              : DateTime.parse(r['last_message_at'] as String),
          unreadCount: (r['unread_count'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<Conversation> getOrCreateConversation(String otherUserId) async {
    final id = await _client.rpc('get_or_create_conversation',
        params: {'p_other': otherUserId}) as String;
    final rows = await _client.rpc('my_conversations') as List;
    final row =
        rows.firstWhere((r) => r['id'] == id, orElse: () => rows.first);
    return Conversation(
      id: id,
      participants: [
        for (final p in (row['participants'] as List))
          profileFromRow(p as Map<String, dynamic>),
      ],
    );
  }

  @override
  Future<List<Message>> messages(String conversationId) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return [
      for (final r in rows)
        Message(
          id: r['id'] as String,
          conversationId: conversationId,
          senderId: r['sender_id'] as String,
          content: r['content'] as String,
          read: r['read'] as bool? ?? false,
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
    ];
  }

  @override
  Future<Message> sendMessage(String conversationId, String content) async {
    final row = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': _me,
          'content': content,
        })
        .select()
        .single();
    return Message(
      id: row['id'] as String,
      conversationId: conversationId,
      senderId: _me,
      content: content,
      read: true,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  Future<void> markRead(String conversationId) async {
    await _client
        .from('messages')
        .update({'read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', _me);
  }

  // -- Grupos (§20–§26) — RPCs definidos em schema.sql ---------------------

  @override
  Future<Conversation> createGroup({
    required String name,
    String? imageUrl,
    required List<String> invitedUserIds,
  }) async {
    final id = await _client.rpc('create_group', params: {
      'p_name': name,
      'p_image_url': imageUrl,
      'p_invited': invitedUserIds,
    }) as String;
    final rows = await _client.rpc('my_conversations') as List;
    final row =
        rows.firstWhere((r) => r['id'] == id, orElse: () => rows.first);
    return _groupFromRow(row as Map<String, dynamic>);
  }

  @override
  Future<List<GroupInvite>> myPendingInvites() async {
    final rows = await _client
        .from('group_invites')
        .select()
        .eq('invited_user_id', _me)
        .eq('status', 'pending');
    return [for (final r in rows) _inviteFromRow(r)];
  }

  @override
  Future<({Conversation group, UserProfile inviter})> inviteContext(
      GroupInvite invite) async {
    final group = await _client
        .from('conversations')
        .select()
        .eq('id', invite.groupId)
        .single();
    final inviter = await _client
        .from('profiles')
        .select()
        .eq('id', invite.inviterId)
        .single();
    return (
      group: _groupFromRow(group),
      inviter: profileFromRow(inviter),
    );
  }

  @override
  Future<Conversation> acceptInvite(String inviteId) async {
    // A RPC valida server-side que só o convidado aceita (§25).
    final groupId =
        await _client.rpc('accept_group_invite', params: {'p_invite': inviteId})
            as String;
    final group = await _client
        .from('conversations')
        .select()
        .eq('id', groupId)
        .single();
    return _groupFromRow(group);
  }

  @override
  Future<void> ignoreInvite(String inviteId) async {
    await _client
        .from('group_invites')
        .update({'status': 'ignored'})
        .eq('id', inviteId)
        .eq('invited_user_id', _me);
  }

  @override
  Future<GroupRole?> myRoleIn(String conversationId) async {
    final row = await _client
        .from('conversation_participants')
        .select('role')
        .eq('conversation_id', conversationId)
        .eq('user_id', _me)
        .maybeSingle();
    if (row == null) return null;
    return GroupRole.values.firstWhere(
      (r) => r.name == row['role'],
      orElse: () => GroupRole.member,
    );
  }

  static Conversation _groupFromRow(Map<String, dynamic> r) => Conversation(
        id: r['id'] as String,
        type: r['type'] == 'group'
            ? ConversationType.group
            : ConversationType.direct,
        name: r['name'] as String?,
        imageUrl: r['image_url'] as String?,
        createdBy: r['created_by'] as String?,
        participants: [
          if (r['participants'] is List)
            for (final p in (r['participants'] as List))
              profileFromRow(p as Map<String, dynamic>),
        ],
        lastMessage: r['last_message'] as String?,
        lastMessageAt: r['last_message_at'] == null
            ? null
            : DateTime.parse(r['last_message_at'] as String),
        unreadCount: (r['unread_count'] as num?)?.toInt() ?? 0,
      );

  static GroupInvite _inviteFromRow(Map<String, dynamic> r) => GroupInvite(
        id: r['id'] as String,
        groupId: r['group_id'] as String,
        inviterId: r['inviter_id'] as String,
        invitedUserId: r['invited_user_id'] as String,
        token: r['token'] as String,
        status: InviteStatus.values.firstWhere(
          (s) => s.name == r['status'],
          orElse: () => InviteStatus.pending,
        ),
        createdAt: DateTime.parse(r['created_at'] as String),
        expiresAt: DateTime.parse(r['expires_at'] as String),
      );
}

/// Escolas e comunicados no Supabase (§8, §37–§40).
class SupabaseSchoolRepository implements SchoolRepository {
  SupabaseSchoolRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<School>> listSchools({String query = ''}) async {
    var q = _client.from('schools').select().eq('active', true);
    if (query.trim().isNotEmpty) {
      q = q.ilike('name', '%${query.trim()}%');
    }
    final rows = await q.order('name');
    return [for (final r in rows) _schoolFromRow(r)];
  }

  @override
  Future<School?> getById(String id) async {
    final row =
        await _client.from('schools').select().eq('id', id).maybeSingle();
    return row == null ? null : _schoolFromRow(row);
  }

  @override
  Future<List<SchoolAnnouncement>> announcementsOf(String schoolId) async {
    final rows = await _client
        .from('school_announcements')
        .select()
        .eq('school_id', schoolId)
        .order('created_at', ascending: false);
    return [for (final r in rows) _announcementFromRow(r)];
  }

  @override
  Future<SchoolAnnouncement> createAnnouncement({
    required String schoolId,
    required String title,
    String? subtitle,
    required String content,
    required AnnouncementCategory category,
  }) async {
    // RLS no backend garante que apenas Developers inserem (§47).
    final row = await _client
        .from('school_announcements')
        .insert({
          'school_id': schoolId,
          'author_id': _client.auth.currentUser!.id,
          'title': title,
          'subtitle': subtitle,
          'content': content,
          'category': category.name,
        })
        .select()
        .single();
    return _announcementFromRow(row);
  }

  @override
  Future<void> updateAnnouncement(
    String id, {
    String? title,
    String? subtitle,
    String? content,
    AnnouncementCategory? category,
  }) async {
    await _client.from('school_announcements').update({
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (content != null) 'content': content,
      if (category != null) 'category': category.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    await _client.from('school_announcements').delete().eq('id', id);
  }

  /// Estatísticas da escola calculadas no BANCO via RPC `school_stats`
  /// (rodada 6): alunos únicos por school_id, projetos pelo autor
  /// principal e média de todas as avaliações — nunca hardcoded.
  @override
  Future<SchoolStats> stats(String schoolId) async {
    final row = await _client
        .rpc('school_stats', params: {'p_school_id': schoolId})
        .single();
    return SchoolStats(
      studentCount: (row['student_count'] as num).toInt(),
      projectCount: (row['project_count'] as num).toInt(),
      ratingAvg: (row['rating_avg'] as num).toDouble(),
      ratingCount: (row['rating_count'] as num).toInt(),
    );
  }

  static School _schoolFromRow(Map<String, dynamic> r) => School(
        id: r['id'] as String,
        name: r['name'] as String,
        city: r['city'] as String? ?? '',
        state: r['state'] as String? ?? '',
        logoUrl: r['logo_url'] as String?,
        active: r['active'] as bool? ?? true,
      );

  static SchoolAnnouncement _announcementFromRow(Map<String, dynamic> r) =>
      SchoolAnnouncement(
        id: r['id'] as String,
        schoolId: r['school_id'] as String,
        authorId: r['author_id'] as String,
        title: r['title'] as String,
        subtitle: r['subtitle'] as String?,
        content: r['content'] as String,
        category: AnnouncementCategory.values.firstWhere(
          (c) => c.name == r['category'],
          orElse: () => AnnouncementCategory.geral,
        ),
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: r['updated_at'] == null
            ? null
            : DateTime.parse(r['updated_at'] as String),
      );
}

/// Pesquisa global no Supabase (§27–§33).
class SupabaseSearchRepository implements SearchRepository {
  SupabaseSearchRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<GlobalSearchResults> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const GlobalSearchResults();
    final pattern = '%$q%';

    final users = await _client
        .from('profiles')
        .select()
        .or('name.ilike.$pattern,username.ilike.$pattern')
        .limit(20);
    final projects = await _client
        .from('projects')
        .select('*, project_media(*)')
        .or('title.ilike.$pattern,subtitle.ilike.$pattern,description.ilike.$pattern')
        .limit(20);
    final materials = await _client
        .from('material_posts')
        .select('*, profiles(*)')
        .or('title.ilike.$pattern,content.ilike.$pattern')
        .limit(20);

    return GlobalSearchResults(
      users: [for (final r in users) profileFromRow(r)],
      projects: [
        for (final r in projects) SupabaseProjectRepository.projectFromRow(r)
      ],
      materials: [
        for (final r in materials)
          SupabaseMaterialRepository.postFromRow(r)
      ],
    );
  }
}

/// Notificações (rodada 4, §21) — preparado, ainda NÃO conectado.
/// A criação das linhas acontece no backend (triggers/RPCs, ver
/// supabase/schema.sql); o app apenas lê as próprias notificações e
/// marca como lidas — RLS garante que cada um só vê as suas.
class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  static AppNotification _fromRow(Map<String, dynamic> r) => AppNotification(
        id: r['id'] as String,
        recipientUserId: r['recipient_user_id'] as String,
        type: NotificationType.values.firstWhere(
          (t) => t.name == r['type'],
          orElse: () => NotificationType.system,
        ),
        actorUserId: r['actor_user_id'] as String?,
        referenceId: r['reference_id'] as String?,
        title: r['title'] as String,
        message: r['message'] as String,
        count: (r['count'] as int?) ?? 1,
        createdAt: DateTime.parse(r['created_at'] as String),
        readAt: r['read_at'] == null
            ? null
            : DateTime.parse(r['read_at'] as String),
      );

  @override
  Future<List<AppNotification>> notificationsOf(String userId) async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('recipient_user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return [for (final r in rows) _fromRow(r)];
  }

  @override
  Future<int> unreadCount(String userId) async {
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('recipient_user_id', userId)
        .filter('read_at', 'is', null);
    return rows.length;
  }

  @override
  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', notificationId)
        .filter('read_at', 'is', null);
  }

  @override
  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('recipient_user_id', userId)
        .filter('read_at', 'is', null);
  }
}

/// Biblioteca (rodada 4, §37) — usa a tabela `saves` já existente
/// (relação única userId + projectId com RLS privada, §32/§38).
/// Preparado, ainda NÃO conectado.
class SupabaseSavedProjectsRepository implements SavedProjectsRepository {
  SupabaseSavedProjectsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SavedProject>> savedRelations(String userId) async {
    final rows = await _client
        .from('saves')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        SavedProject(
          userId: r['user_id'] as String,
          projectId: r['project_id'] as String,
          savedAt: DateTime.parse(r['created_at'] as String),
        ),
    ];
  }

  @override
  Future<bool> isSaved(String userId, String projectId) async {
    final rows = await _client
        .from('saves')
        .select('project_id')
        .eq('user_id', userId)
        .eq('project_id', projectId);
    return rows.isNotEmpty;
  }

  @override
  Future<bool> toggle(String userId, String projectId) async {
    if (await isSaved(userId, projectId)) {
      await _client
          .from('saves')
          .delete()
          .eq('user_id', userId)
          .eq('project_id', projectId);
      return false;
    }
    await _client.from('saves').insert({
      'user_id': userId,
      'project_id': projectId,
    });
    return true;
  }
}

/// Denúncias de projetos no Supabase (rodada 6). A tabela `reports`
/// tem RLS: cada usuário só vê as PRÓPRIAS denúncias; a fila completa
/// fica visível apenas para Developers. O autor do projeto denunciado
/// nunca tem acesso à identidade de quem denunciou.
class SupabaseReportRepository implements ReportRepository {
  SupabaseReportRepository(this._client);

  final SupabaseClient _client;

  static ProjectReport _fromRow(Map<String, dynamic> r) => ProjectReport(
        id: r['id'] as String,
        projectId: r['project_id'] as String,
        reporterUserId: r['reporter_id'] as String,
        reason: ReportReasonX.fromStorageKey(r['reason'] as String),
        description: r['description'] as String?,
        status: ReportStatusX.fromStorageKey(r['status'] as String),
        createdAt: DateTime.parse(r['created_at'] as String),
        reviewedAt: r['reviewed_at'] == null
            ? null
            : DateTime.parse(r['reviewed_at'] as String),
        reviewedBy: r['reviewed_by'] as String?,
      );

  @override
  Future<ProjectReport> reportProject(
    String projectId, {
    required ReportReason reason,
    String? description,
  }) async {
    final uid = _client.auth.currentUser!.id;
    // Sem denúncias pendentes duplicadas do mesmo usuário no mesmo
    // projeto — retorna a que já está na fila (há também índice UNIQUE
    // parcial no banco como segunda barreira).
    final existing = await _client
        .from('reports')
        .select()
        .eq('project_id', projectId)
        .eq('reporter_id', uid)
        .eq('status', 'pending')
        .maybeSingle();
    if (existing != null) return _fromRow(existing);

    final row = await _client
        .from('reports')
        .insert({
          'project_id': projectId,
          'reporter_id': uid,
          'reason': reason.storageKey,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        })
        .select()
        .single();
    return _fromRow(row);
  }

  @override
  Future<List<ProjectReport>> myPendingReports() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('reports')
        .select()
        .eq('reporter_id', uid)
        .eq('status', 'pending');
    return [for (final r in rows) _fromRow(r)];
  }

  @override
  Future<List<ProjectReport>> pendingReports() async {
    final rows = await _client
        .from('reports')
        .select()
        .eq('status', 'pending')
        .order('created_at');
    return [for (final r in rows) _fromRow(r)];
  }

  @override
  Future<void> reviewReport(String reportId, ReportStatus result) async {
    await _client.from('reports').update({
      'status': result.storageKey,
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': _client.auth.currentUser!.id,
    }).eq('id', reportId);
  }
}
