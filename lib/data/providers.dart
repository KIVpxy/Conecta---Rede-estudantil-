import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/config.dart';
import 'models/models.dart';
import 'repositories/mock/mock_database.dart';
import 'repositories/mock/mock_repositories.dart';
import 'repositories/repositories.dart';
import 'repositories/supabase/supabase_repositories.dart';

/// Escolhe mock vs Supabase conforme AppConfig.useMock.

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.useMock) return MockAuthRepository(MockDatabase.instance);
  return SupabaseAuthRepository(Supabase.instance.client);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (AppConfig.useMock) return MockProfileRepository(MockDatabase.instance);
  return SupabaseProfileRepository(Supabase.instance.client);
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  if (AppConfig.useMock) return MockProjectRepository(MockDatabase.instance);
  return SupabaseProjectRepository(Supabase.instance.client);
});

final rankingRepositoryProvider = Provider<RankingRepository>((ref) {
  if (AppConfig.useMock) return MockRankingRepository(MockDatabase.instance);
  return SupabaseRankingRepository(Supabase.instance.client);
});

final badgeRepositoryProvider = Provider<BadgeRepository>((ref) {
  if (AppConfig.useMock) return MockBadgeRepository(MockDatabase.instance);
  return SupabaseBadgeRepository(Supabase.instance.client);
});

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  if (AppConfig.useMock) return MockMaterialRepository(MockDatabase.instance);
  return SupabaseMaterialRepository(Supabase.instance.client);
});

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  if (AppConfig.useMock) return MockMessagingRepository(MockDatabase.instance);
  return SupabaseMessagingRepository(Supabase.instance.client);
});

final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  if (AppConfig.useMock) return MockSchoolRepository(MockDatabase.instance);
  return SupabaseSchoolRepository(Supabase.instance.client);
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  if (AppConfig.useMock) return MockSearchRepository(MockDatabase.instance);
  return SupabaseSearchRepository(Supabase.instance.client);
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (AppConfig.useMock) {
    return MockNotificationRepository(MockDatabase.instance);
  }
  return SupabaseNotificationRepository(Supabase.instance.client);
});

final savedProjectsRepositoryProvider =
    Provider<SavedProjectsRepository>((ref) {
  if (AppConfig.useMock) {
    return LocalSavedProjectsRepository(MockDatabase.instance);
  }
  return SupabaseSavedProjectsRepository(Supabase.instance.client);
});

/// Denúncias de projetos (rodada 6) — mock hoje, Supabase sem trocar UI.
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  if (AppConfig.useMock) {
    return LocalReportRepository(MockDatabase.instance);
  }
  return SupabaseReportRepository(Supabase.instance.client);
});

/// Projetos salvos pelo usuário logado, com a relação já resolvida em
/// Project. Projetos removidos não viram cópia falsa na Biblioteca:
/// a relação simplesmente deixa de resolver (§33).
final savedProjectsProvider = FutureProvider<List<Project>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  final relations =
      await ref.watch(savedProjectsRepositoryProvider).savedRelations(user.id);
  final projects = ref.watch(projectRepositoryProvider);
  final result = <Project>[];
  for (final rel in relations) {
    final project = await projects.getById(rel.projectId);
    if (project != null) result.add(project);
  }
  return result;
});

/// Projeto individual por ID — compartilhado entre a página de
/// detalhe e a de edição (invalidar aqui reflete nas duas).
final projectByIdProvider =
    FutureProvider.family<Project?, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).getById(id);
});

/// Estatísticas reais da escola (rodada 6): alunos únicos por schoolId,
/// projetos pelo autor principal e média de todas as avaliações.
/// Público para que criar/excluir projeto ou nova avaliação possam
/// invalidar e atualizar a aba Escola sem reload.
final schoolStatsProvider =
    FutureProvider.family<SchoolStats, String>((ref, schoolId) {
  ref.watch(currentUserProvider);
  return ref.watch(schoolRepositoryProvider).stats(schoolId);
});

/// Usuário atualmente logado (null = deslogado).
final currentUserProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(authRepositoryProvider).watchCurrentUser();
});

/// Rank do usuário logado (para molduras de avatar na navegação).
final currentUserRankProvider = FutureProvider<RankTier>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return RankTier.bronze;
  return ref.watch(profileRepositoryProvider).rankOf(user.id);
});
